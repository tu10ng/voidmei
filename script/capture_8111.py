#!/usr/bin/env python3
# /// script
# requires-python = ">=3.8"
# dependencies = []
# ///
"""
8111 遥测抓包器 — 高频抓战雷原始 state/indicators, 诊断哨兵值(-65535)/字段缺失/数值跳变.

用法:
    uv run script/capture_8111.py                # 默认 8111, 100ms 一轮, Ctrl+C 停
    python script/capture_8111.py --duration 60  # 60 秒后自动停
    python script/capture_8111.py --only state   # 只抓 state 一个端点
抓包期间在终端回车输入文字可打标记 (对齐游戏内动作时刻).
结束后打印哨兵/缺失统计; 原始 JSON 逐条存 jsonl, 每行: {"ts":..., "ep":..., "ok":..., ...}.
"""

import argparse
import json
import os
import sys
import threading
import time
import urllib.request

INVALID = -65535            # 与 StringHelper.fInvalid 同源的哨兵值
MERGE_GAP_FACTOR = 4        # 相邻事件间隔 < interval*该倍数 时合并为同一时间段


def fmt_ts(epoch):
    lt = time.localtime(epoch)
    return "%02d:%02d:%02d.%03d" % (lt.tm_hour, lt.tm_min, lt.tm_sec, int(epoch * 1000) % 1000)


class Grabber:
    def __init__(self, port, interval, endpoints, out_path, verbose):
        # 路径自动探测: 战雷真机两个路径都应答过 (VoidMei 用 /state, 社区文档用 /state.json),
        # mock 只有 /state — 首次 404 时轮换候选, 命中后缓存
        self.paths = {ep: ["/%s.json" % ep, "/%s" % ep] for ep in endpoints}
        self.base = "http://127.0.0.1:%d" % port
        self.interval = interval
        self.out_path = out_path
        self.verbose = verbose
        # 显式禁用代理: 本机环境变量里的 HTTP_PROXY 会让 urllib 把 127.0.0.1 请求发进 Clash
        self.opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        self.out = open(out_path, "a", encoding="utf-8")
        self.seen_fields = {ep: set() for ep in endpoints}   # 各端点见过的字段并集 (缺失检测基准)
        self.bad_state = {ep: None for ep in endpoints}      # 上一轮的异常字段集, 变化才打印
        self.events = []    # (epoch, "字段名", ep) — 哨兵/缺失/标记事件, 结束时聚合
        self.counts = {"tick": 0, "ok": 0, "fail": 0}
        self.lock = threading.Lock()
        self.t_start = time.time()

    # ---------- 单次抓取 ----------

    def grab(self, ep):
        self.counts["tick"] += 1
        candidates = self.paths[ep]
        data = None
        err = None
        for path in candidates:
            try:
                req = urllib.request.Request(self.base + path, headers={"Connection": "close"})
                with self.opener.open(req, timeout=1.0) as resp:
                    data = json.loads(resp.read().decode("utf-8", "replace"))
                self.paths[ep] = [path]   # 命中后固定, 不再轮换
                break
            except Exception as e:
                err = e
        if data is None:
            self.counts["fail"] += 1
            self.record({"ts": time.time(), "ep": ep, "ok": False, "err": str(err)})
            self.print_line(ep, "ERR: %s" % err)
            return
        self.counts["ok"] += 1
        self.record({"ts": time.time(), "ep": ep, "ok": True, "body": data})

        # 哨兵/缺失检测 (缺失 = 本会话见过但本帧没有)
        sent = {k for k, v in data.items()
                if isinstance(v, (int, float)) and not isinstance(v, bool) and v == INVALID}
        self.seen_fields[ep] |= set(data.keys())
        missing = self.seen_fields[ep] - set(data.keys())
        now = time.time()
        for k in sent:
            self.events.append((now, ep, k, "哨兵"))
        for k in missing:
            self.events.append((now, ep, k, "缺失"))

        bad = sent | missing
        if bad != self.bad_state[ep]:
            self.bad_state[ep] = bad
            if bad:
                self.print_line(ep, "异常 %d 字段: %s" % (len(bad), ", ".join(sorted(bad))))
            else:
                self.print_line(ep, "恢复正常")
        elif self.verbose:
            self.print_line(ep, "ok (%d 字段)" % len(data))

    # ---------- 输出 ----------

    def print_line(self, ep, msg):
        print("[%s] %-10s %s" % (fmt_ts(time.time()), ep, msg), flush=True)

    def record(self, obj):
        with self.lock:
            self.out.write(json.dumps(obj, ensure_ascii=False) + "\n")
            self.out.flush()

    def mark(self, text):
        now = time.time()
        self.events.append((now, "-", "[标记] " + text, "标记"))
        self.record({"ts": now, "mark": text})
        print("[%s] --- 标记: %s ---" % (fmt_ts(now), text), flush=True)

    # ---------- 结束统计 ----------

    def report(self):
        dur = time.time() - self.t_start
        print("\n== 抓包统计 ==")
        print("时长 %.1fs, 请求 %d 次 (成功 %d / 失败 %d)" %
              (dur, self.counts["tick"], self.counts["ok"], self.counts["fail"]))
        marks = [(t, f) for t, ep, f, kind in self.events if kind == "标记"]
        if marks:
            print("标记: " + "; ".join("%s %s" % (fmt_ts(t), f) for t, f in marks))

        # 按 (端点, 字段, 类型) 聚合, 时间相邻的合并为段
        groups = {}
        for t, ep, field, kind in self.events:
            if kind == "标记":
                continue
            groups.setdefault((ep, field, kind), []).append(t)
        if not groups:
            print("哨兵值/缺失: 无")
            return
        print("== 哨兵值/缺失字段统计 ==")
        gap = self.interval * MERGE_GAP_FACTOR
        for (ep, field, kind) in sorted(groups):
            times = sorted(groups[(ep, field, kind)])
            spans = []
            for t in times:
                if spans and t - spans[-1][1] <= gap:
                    spans[-1][1] = t
                else:
                    spans.append([t, t])
            total = sum(b - a for a, b in spans)
            detail = "; ".join("%s~%s" % (fmt_ts(a), fmt_ts(b)) for a, b in spans[:6])
            if len(spans) > 6:
                detail += "; ...(%d 段)" % len(spans)
            print("%-12s %-4s %-22s %3d 段 %6.1fs  %s" %
                  (ep, kind, field, len(spans), total, detail))


def main():
    ap = argparse.ArgumentParser(description="8111 遥测抓包器")
    ap.add_argument("--port", type=int, default=8111)
    ap.add_argument("--interval", type=float, default=0.1, help="轮询间隔秒 (默认 0.1)")
    ap.add_argument("--duration", type=float, default=0, help="自动停止时长秒 (0=Ctrl+C 手动停)")
    ap.add_argument("--only", choices=["state", "indicators"], help="只抓一个端点")
    ap.add_argument("--out", help="输出 jsonl 路径 (默认 %%TEMP%%\\capture_8111_时间戳.jsonl)")
    ap.add_argument("-v", "--verbose", action="store_true", help="每轮都打印, 不只异常时")
    args = ap.parse_args()

    endpoints = [args.only] if args.only else ["state", "indicators"]
    out_path = args.out or os.path.join(
        os.environ.get("TEMP", "."), "capture_8111_%s.jsonl" % time.strftime("%Y%m%d_%H%M%S"))
    g = Grabber(args.port, args.interval, endpoints, out_path, args.verbose)

    # 标记线程: 终端回车输入文字 -> 打时间标记 (游戏全屏时不可用, 切出游戏再按)
    def marker():
        while True:
            try:
                text = input()
            except EOFError:
                return
            if text.strip():
                g.mark(text.strip())

    threading.Thread(target=marker, daemon=True).start()

    print("抓包中 -> %s (Ctrl+C 停止; 回车可打标记)" % out_path, flush=True)
    try:
        deadline = time.monotonic()
        while True:
            deadline += args.interval
            for ep in endpoints:
                g.grab(ep)
            if args.duration and time.time() - g.t_start >= args.duration:
                break
            remain = deadline - time.monotonic()
            if remain > 0:
                time.sleep(remain)
    except KeyboardInterrupt:
        pass
    finally:
        g.report()
        print("原始数据: %s" % out_path)


if __name__ == "__main__":
    main()
