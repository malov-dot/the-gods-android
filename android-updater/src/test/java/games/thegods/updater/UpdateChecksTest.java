package games.thegods.updater;

import org.junit.Rule;
import org.junit.Test;
import org.junit.rules.TemporaryFolder;
import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.util.Arrays;
import java.util.HashSet;
import java.util.Set;
import static org.junit.Assert.*;

public class UpdateChecksTest {
    @Rule public TemporaryFolder temporary = new TemporaryFolder();
    private Set<String> keys(String... values) { return new HashSet<>(Arrays.asList(values)); }
    private void rejected(ThrowingRunnable action) throws Exception {
        try { action.run(); fail("Expected this unsafe update to be rejected."); }
        catch (IOException expected) { assertFalse(expected.getMessage().isEmpty()); }
    }
    private interface ThrowingRunnable { void run() throws Exception; }

    @Test public void onlyPrivateUpdateFileIsAccepted() throws Exception {
        File files = temporary.newFolder("files");
        File updates = new File(files, "updates");
        assertTrue(updates.mkdir());
        File apk = new File(updates, "update.apk");
        Files.write(apk.toPath(), new byte[]{1,2,3});
        assertEquals(apk, UpdateChecks.requireUpdateFile(files, apk.getAbsolutePath()));
        File other = temporary.newFile("different.apk");
        Files.write(other.toPath(), new byte[]{1,2,3});
        rejected(() -> UpdateChecks.requireUpdateFile(files, other.getAbsolutePath()));
        rejected(() -> UpdateChecks.requireUpdateFile(files, "updates/update.apk"));
    }
    @Test public void missingAndEmptyUpdatesAreRejected() throws Exception {
        File files = temporary.newFolder("files");
        File updates = new File(files, "updates");
        assertTrue(updates.mkdir());
        File apk = new File(updates, "update.apk");
        rejected(() -> UpdateChecks.requireUpdateFile(files, apk.getAbsolutePath()));
        assertTrue(apk.createNewFile());
        rejected(() -> UpdateChecks.requireUpdateFile(files, apk.getAbsolutePath()));
    }
    @Test public void boundedFileSizesAreEnforced() throws Exception {
        UpdateChecks.requireLength(1);
        UpdateChecks.requireLength(UpdateChecks.MAX_APK_BYTES);
        rejected(() -> UpdateChecks.requireLength(0));
        rejected(() -> UpdateChecks.requireLength(-1));
        rejected(() -> UpdateChecks.requireLength(UpdateChecks.MAX_APK_BYTES + 1));
    }
    @Test public void knownSha256AndCaseAreSupported() throws Exception {
        File file = temporary.newFile("digest.apk");
        Files.write(file.toPath(), "abc".getBytes(java.nio.charset.StandardCharsets.UTF_8));
        String expected = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad";
        assertEquals(expected, UpdateChecks.sha256(file));
        UpdateChecks.requireDigest(expected.toUpperCase(java.util.Locale.ROOT), UpdateChecks.sha256(file));
        rejected(() -> UpdateChecks.requireDigest("", expected));
        rejected(() -> UpdateChecks.requireDigest(null, expected));
        rejected(() -> UpdateChecks.requireDigest("x".repeat(64), expected));
    }
    @Test public void changedDownloadCannotReuseItsVerification() throws Exception {
        File file = temporary.newFile("changed.apk");
        Files.write(file.toPath(), new byte[]{1,2,3});
        String verified = UpdateChecks.sha256(file);
        Files.write(file.toPath(), new byte[]{1,2,4});
        rejected(() -> UpdateChecks.requireDigest(verified, UpdateChecks.sha256(file)));
    }
    @Test public void newerSameGameSameKeyIsAccepted() throws Exception {
        UpdateChecks.requireMetadata("games.thegods.sandbox", "games.thegods.sandbox", 10400, 10401, 10401, keys("A"), keys("A"));
    }
    @Test public void unrelatedPackagesAreRejected() throws Exception {
        rejected(() -> UpdateChecks.requireMetadata("games.thegods.sandbox", "games.other", 10400, 10401, 10401, keys("A"), keys("A")));
    }
    @Test public void DowngradeReplayAndWrongAnnouncedVersionAreRejected() throws Exception {
        rejected(() -> UpdateChecks.requireMetadata("app", "app", 10400, 10399, 10399, keys("A"), keys("A")));
        rejected(() -> UpdateChecks.requireMetadata("app", "app", 10400, 10400, 10400, keys("A"), keys("A")));
        rejected(() -> UpdateChecks.requireMetadata("app", "app", 10400, 10401, 10402, keys("A"), keys("A")));
        rejected(() -> UpdateChecks.requireMetadata("app", "app", 10400, 10401, 0, keys("A"), keys("A")));
    }
    @Test public void unsignedAndDifferentSigningKeysAreRejected() throws Exception {
        rejected(() -> UpdateChecks.requireMetadata("app", "app", 1, 2, 2, keys("A"), keys()));
        rejected(() -> UpdateChecks.requireMetadata("app", "app", 1, 2, 2, keys(), keys("A")));
        rejected(() -> UpdateChecks.requireMetadata("app", "app", 1, 2, 2, keys("A"), keys("B")));
    }
    @Test public void multipleSignerOrderIsIrrelevantButSetsMustMatch() throws Exception {
        UpdateChecks.requireMetadata("app", "app", 1, 2, 2, keys("A","B"), keys("B","A"));
        rejected(() -> UpdateChecks.requireMetadata("app", "app", 1, 2, 2, keys("A","B"), keys("A")));
        rejected(() -> UpdateChecks.requireMetadata("app", "app", 1, 2, 2, keys("A"), keys("A","B")));
    }
}
