package helpers;

public final class Helpers {
    public static String toHexString(long number, long width) {
        return "0x" + String.format("%1$0" + width + "X", number);
    }
}
