package games.thegods.updater;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.Set;

/** Pure validation rules shared by the native bridge and its JVM tests. */
final class UpdateChecks {
    static final long MAX_APK_BYTES = 512L * 1024 * 1024;

    static File requireUpdateFile(File filesDir, String path) throws IOException {
        File base = filesDir.getCanonicalFile();
        File updateDir = new File(base, "updates");
        if (!updateDir.getCanonicalFile().equals(updateDir)) throw new IOException("The update directory is not private app storage.");
        File expected = new File(updateDir, "update.apk");
        File requested = new File(path);
        if (!requested.isAbsolute() || !requested.getCanonicalFile().equals(expected)) throw new IOException("Only this app's private update APK can be installed.");
        if (!expected.isFile()) throw new IOException("The downloaded update is missing.");
        requireLength(expected.length());
        return expected;
    }

    static void requireLength(long length) throws IOException {
        if (length <= 0 || length > MAX_APK_BYTES) throw new IOException("The update has an invalid file size.");
    }

    static void requireDigest(String expected, String actual) throws IOException {
        if (expected == null || !expected.matches("[a-fA-F0-9]{64}") || !expected.equalsIgnoreCase(actual))
            throw new IOException("The downloaded update does not match its SHA-256 checksum.");
    }

    static String sha256(File file) throws IOException {
        requireLength(file.length());
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            long readTotal = 0;
            byte[] bytes = new byte[65536];
            try (FileInputStream input = new FileInputStream(file)) {
                int count;
                while ((count = input.read(bytes)) != -1) {
                    readTotal += count;
                    if (readTotal > MAX_APK_BYTES || Thread.currentThread().isInterrupted()) throw new IOException("Update verification was interrupted.");
                    digest.update(bytes, 0, count);
                }
            }
            requireLength(readTotal);
            return hex(digest.digest());
        } catch (NoSuchAlgorithmException impossible) { throw new IOException("SHA-256 is unavailable.", impossible); }
    }

    static String hex(byte[] data) {
        StringBuilder result = new StringBuilder(data.length * 2);
        for (byte value : data) result.append(String.format(java.util.Locale.ROOT, "%02x", value & 255));
        return result.toString();
    }

    static void requireMetadata(String installedPackage, String candidatePackage, long installedVersion,
            long candidateVersion, long expectedVersion, Set<String> installedSigners, Set<String> candidateSigners) throws IOException {
        if (installedPackage == null || !installedPackage.equals(candidatePackage)) throw new IOException("This update belongs to a different app.");
        if (expectedVersion <= 0 || candidateVersion != expectedVersion) throw new IOException("The APK version does not match the update announcement.");
        if (candidateVersion <= installedVersion) throw new IOException("This APK is not newer than the installed game.");
        if (installedSigners.isEmpty() || candidateSigners.isEmpty() || !installedSigners.equals(candidateSigners))
            throw new IOException("This update was not signed by the installed game's signing key.");
    }
}
