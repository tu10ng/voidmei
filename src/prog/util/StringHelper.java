package prog.util;

public class StringHelper {

    public static final int iInvalid = -65535;
    public static final double fInvalid = -65535;

    public static void getStringBuilder(StringBuilder R, String S, char buf[], int buflen) {
        int bix;
        int eix;
        bix = R.lastIndexOf(S);

        if (bix >= 0) {
            eix = bix;
            while (eix < R.length() && R.charAt(eix) != ':') {
                eix++;
            }
            eix++;
            bix = eix + 1;
            while (eix < R.length() && R.charAt(eix) != ',' && R.charAt(eix) != '}') {
                eix++;
            }

            R.getChars(bix, eix, buf, buflen);
        }

    }

    /**
     * 单键 JSON 帧判定: 整帧只有一对键值 (实测战雷在选机/返回基地等状态转换窗口,
     * state 端点会发只剩 {"valid": true} 的空壳帧, 字段全缺失会解析成哨兵 -65535)。
     * 判据: 帧内只有一个冒号 → 只有一对键值。正常遥测帧 30+ 字段不会误伤。
     */
    public static boolean isSingleKeyFrame(String buf) {
        if (buf == null) {
            return false;
        }
        int first = buf.indexOf(':');
        return first >= 0 && buf.indexOf(':', first + 1) < 0;
    }

    public static String getString(String R, String S) {
        int bix;
        int eix;
        bix = R.indexOf(S);
        if (bix >= 0) {
            eix = bix;
            while (eix < R.length() && R.charAt(eix) != ':') {
                eix++;
            }
            eix++;
            bix = eix + 1;
            while (eix < R.length() && R.charAt(eix) != ',' && R.charAt(eix) != '}') {
                eix++;
            }

            return R.substring(bix, eix);
        } else
            return null;
    }

    public static double getDataFloatC(CharSequence cs) {
        if (cs != null)
            return Float.parseFloat(cs.toString());
        else
            return fInvalid;
    }

    public static double getDataIntC(CharSequence cs) {
        if (cs != null)
            return Integer.parseInt(cs.toString());
        else
            return iInvalid;
    }

    public static double getDataFloat(String sdata) {
        if (sdata != null)
            return Float.parseFloat(sdata);
        else
            return fInvalid;
    }

    public static int getDataInt(String sdata) {
        if (sdata != null)
            return Integer.parseInt(sdata);
        else
            return iInvalid;
    }

}
