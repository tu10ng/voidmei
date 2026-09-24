import java.io.File;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Paths;

import parser.Indicators;
import parser.State;

/**
 * 战雷空壳单键帧防御验证 —— 数据来自 script/mock_scenarios/snapshots/real_empty_shell.json
 * (2026-09-25 capture_8111 真机抓包: 选机/载入/RTB 等转换窗口, state 与 indicators 都会发
 * 只剩 {"valid": false} 的单键帧)。
 *
 * 断言: 单键帧按无效帧丢弃 (flag=false; State 返回 0 而非 -1, -1 会让 Service 误翻轮询端口),
 * 且不覆盖已有字段。
 *
 * Run with: python script/build.py test real8111
 */
public class TestReal8111Scenarios {

	private static int passed = 0;
	private static int failed = 0;

	private static void assertTrue(boolean cond, String msg) {
		if (cond) {
			passed++;
			System.out.println("  PASS: " + msg);
		} else {
			failed++;
			System.out.println("  FAIL: " + msg);
		}
	}

	/** 读取快照 (格式: {"/state": "<单行 JSON>", "/indicators": "<单行 JSON>"}) 的端点原文 */
	private static String readBody(String field) throws Exception {
		File f = new File("script/mock_scenarios/snapshots/real_empty_shell.json");
		if (!f.isFile()) {
			return null;
		}
		String text = new String(Files.readAllBytes(Paths.get(f.getPath())), StandardCharsets.UTF_8);
		int key = text.indexOf("\"/" + field + "\"");
		if (key < 0) {
			return null;
		}
		int colon = text.indexOf(':', key);
		int eol = text.indexOf('\n', colon);
		if (colon < 0 || eol < 0) {
			return null;
		}
		String raw = text.substring(colon + 1, eol).trim();
		if (raw.startsWith("\"") && raw.endsWith("\"") && raw.length() >= 2) {
			raw = raw.substring(1, raw.length() - 1).replace("\\\"", "\"").replace("\\\\", "\\");
		}
		return raw;
	}

	public static void main(String[] args) throws Exception {
		String stateBody = readBody("state");
		String indicBody = readBody("indicators");
		if (stateBody == null || indicBody == null) {
			System.out.println("SKIP: 真机快照不存在 (script/mock_scenarios/snapshots/real_empty_shell.json)");
			return;
		}

		State s = new State();
		s.init();
		// 预置字段值: 验证空壳帧不把已有数据冲成哨兵
		s.Ny = 0.98;
		s.IAS = 120;
		int rc = s.update(stateBody);
		assertTrue(rc == 0, "空壳帧: 返回 0 (-1 会让 Service 误翻轮询端口)");
		assertTrue(!s.flag, "空壳帧: flag=false (按无效帧丢弃)");
		assertTrue(s.Ny == 0.98 && s.IAS == 120, "空壳帧: 已有字段不被哨兵覆盖");

		Indicators ind = new Indicators();
		ind.init();
		ind.update(indicBody);
		assertTrue(!ind.flag, "空壳帧: indicators flag=false");

		System.out.println();
		if (failed > 0) {
			System.out.println("RESULT: FAILED (" + failed + " failures)");
			System.exit(1);
		}
		System.out.println("RESULT: PASSED (" + passed + " assertions)");
	}
}
