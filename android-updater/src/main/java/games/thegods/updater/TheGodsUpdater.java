package games.thegods.updater;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.content.pm.Signature;
import android.content.pm.SigningInfo;
import android.net.Uri;
import android.os.Build;
import android.os.Looper;
import android.provider.Settings;
import androidx.annotation.NonNull;
import androidx.core.content.FileProvider;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;
import org.json.JSONObject;
import java.io.File;
import java.io.IOException;
import java.security.MessageDigest;
import java.util.Arrays;
import java.util.HashSet;
import java.util.Set;
import java.util.concurrent.Callable;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.FutureTask;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;

/** Native self-update bridge. Download policy and all game UI remain in GDScript. */
public final class TheGodsUpdater extends GodotPlugin {
    private static final int PERMISSION_REQUEST = 17481;
    private static final int INSTALL_REQUEST = 17482;
    private final ExecutorService verifier = Executors.newSingleThreadExecutor();
    private final AtomicBoolean verifying = new AtomicBoolean();
    private final AtomicBoolean permissionPending = new AtomicBoolean();
    private volatile boolean permissionPaused;
    private volatile boolean destroyed;
    private volatile Candidate verified;
    private volatile Uri installedUri;

    private static final class Candidate {
        final String sha;
        final long version;
        final long length;
        final long modified;
        Candidate(String sha, long version, File file) {
            this.sha=sha; this.version=version; this.length=file.length(); this.modified=file.lastModified();
        }
    }

    public TheGodsUpdater(Godot godot) { super(godot); }
    @NonNull @Override public String getPluginName() { return "TheGodsUpdater"; }
    @NonNull @Override public Set<SignalInfo> getPluginSignals() {
        return new HashSet<>(Arrays.asList(
            new SignalInfo("verification_finished", String.class),
            new SignalInfo("permission_returned", Boolean.class),
            new SignalInfo("installer_returned")));
    }

    @UsedByGodot public String get_installed_info() {
        try {
            Context context = getContext();
            PackageInfo info = installedInfo(context);
            return new JSONObject().put("package_name", info.packageName)
                .put("version_code", version(info)).put("version_name", info.versionName).toString();
        } catch (Exception failure) { return result(false, message(failure)); }
    }

    @UsedByGodot public double get_display_density() {
        return Math.max(0.5, Math.min(8.0, getContext().getResources().getDisplayMetrics().density));
    }

    @UsedByGodot public String get_update_path() {
        File directory = new File(getContext().getFilesDir(), "updates");
        if (!directory.isDirectory() && !directory.mkdirs()) return "";
        return new File(directory, "update.apk").getAbsolutePath();
    }

    @UsedByGodot public void verify_apk(String path, String expectedSha, int expectedVersion) {
        if (!verifying.compareAndSet(false, true)) {
            emitSignal("verification_finished", result(false, "An update is already being verified."));
            return;
        }
        verified = null;
        verifier.execute(() -> {
            String response;
            try {
                File file = UpdateChecks.requireUpdateFile(getContext().getFilesDir(), path);
                String actualSha = UpdateChecks.sha256(file);
                UpdateChecks.requireDigest(expectedSha, actualSha);
                verifyPackage(file, expectedVersion);
                // Rehash after package parsing so a changed download cannot become a verified candidate.
                UpdateChecks.requireDigest(actualSha, UpdateChecks.sha256(file));
                verified = new Candidate(actualSha, expectedVersion, file);
                response = result(true, "The update matches this game, its signing key and the announced version.");
            } catch (Exception failure) { response = result(false, message(failure)); }
            verifying.set(false);
            if (!destroyed) emitSignal("verification_finished", response);
        });
    }

    private void verifyPackage(File file, long expectedVersion) throws Exception {
        Context context = getContext();
        PackageManager manager = context.getPackageManager();
        int flags = Build.VERSION.SDK_INT >= 28 ? PackageManager.GET_SIGNING_CERTIFICATES : PackageManager.GET_SIGNATURES;
        PackageInfo installed = installedInfo(context);
        // Requesting signing information makes Android collect and validate the APK certificates.
        PackageInfo candidate = manager.getPackageArchiveInfo(file.getAbsolutePath(), flags);
        if (candidate == null) throw new IOException("Android could not validate this APK or its signature.");
        if (candidate.applicationInfo != null && candidate.applicationInfo.minSdkVersion > Build.VERSION.SDK_INT)
            throw new IOException("This update requires a newer Android version.");
        Set<String> candidateSigners = signers(candidate);
        if (Build.VERSION.SDK_INT >= 36) {
            SigningInfo checked = PackageManager.getVerifiedSigningInfo(file.getAbsolutePath(), SigningInfo.VERSION_SIGNING_BLOCK_V2);
            candidateSigners = signatureDigests(checked.getApkContentsSigners());
        }
        UpdateChecks.requireMetadata(context.getPackageName(), candidate.packageName, version(installed),
            version(candidate), expectedVersion, signers(installed), candidateSigners);
    }

    @SuppressWarnings("deprecation") private PackageInfo installedInfo(Context context) throws PackageManager.NameNotFoundException {
        int flags = Build.VERSION.SDK_INT >= 28 ? PackageManager.GET_SIGNING_CERTIFICATES : PackageManager.GET_SIGNATURES;
        return context.getPackageManager().getPackageInfo(context.getPackageName(), flags);
    }
    @SuppressWarnings("deprecation") private static long version(PackageInfo info) {
        return Build.VERSION.SDK_INT >= 28 ? info.getLongVersionCode() : info.versionCode;
    }
    @SuppressWarnings("deprecation") private static Set<String> signers(PackageInfo info) throws Exception {
        return signatureDigests(Build.VERSION.SDK_INT >= 28 && info.signingInfo != null
            ? info.signingInfo.getApkContentsSigners() : info.signatures);
    }
    private static Set<String> signatureDigests(Signature[] signatures) throws Exception {
        Set<String> values = new HashSet<>();
        if (signatures != null) for (Signature signature : signatures)
            values.add(UpdateChecks.hex(MessageDigest.getInstance("SHA-256").digest(signature.toByteArray())));
        return values;
    }

    @UsedByGodot public boolean can_install_packages() {
        return Build.VERSION.SDK_INT < 26 || getContext().getPackageManager().canRequestPackageInstalls();
    }
    @UsedByGodot public void request_install_permission() {
        if (can_install_packages()) { emitSignal("permission_returned", true); return; }
        if (!permissionPending.compareAndSet(false, true)) return;
        permissionPaused = false;
        Activity activity = getActivity();
        if (activity == null) { finishPermission(); return; }
        activity.runOnUiThread(() -> {
            try {
                activity.startActivityForResult(new Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:" + activity.getPackageName())), PERMISSION_REQUEST);
            } catch (Exception failure) { finishPermission(); }
        });
    }
    private void finishPermission() {
        if (permissionPending.compareAndSet(true, false) && !destroyed)
            emitSignal("permission_returned", can_install_packages());
    }

    @UsedByGodot public String install_verified_apk() {
        Candidate candidate = verified;
        if (candidate == null || verifying.get()) return "Verify the downloaded update first.";
        if (!can_install_packages()) return "Allow The Gods to request updates in Android settings first.";
        try {
            File file = UpdateChecks.requireUpdateFile(getContext().getFilesDir(), get_update_path());
            if (file.length() != candidate.length || file.lastModified() != candidate.modified)
                throw new IOException("The update file changed. Download and verify it again.");
            UpdateChecks.requireDigest(candidate.sha, UpdateChecks.sha256(file));
            verifyPackage(file, candidate.version);
            Uri uri = FileProvider.getUriForFile(getContext(), getContext().getPackageName() + ".thegods.updates", file);
            Activity activity = getActivity();
            if (activity == null) return "Android's installer is not available right now.";
            Callable<String> launch = () -> {
                // Android owns the confirmation UI and the final install decision.
                Intent intent = new Intent(Intent.ACTION_INSTALL_PACKAGE);
                intent.setData(uri);
                intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                intent.putExtra(Intent.EXTRA_RETURN_RESULT, true);
                activity.startActivityForResult(intent, INSTALL_REQUEST);
                installedUri = uri;
                return "opened";
            };
            if (Looper.myLooper() == Looper.getMainLooper()) return launch.call();
            FutureTask<String> task = new FutureTask<>(launch);
            activity.runOnUiThread(task);
            try { return task.get(5, TimeUnit.SECONDS); }
            catch (Exception failure) { task.cancel(false); throw failure; }
        } catch (Exception failure) { verified = null; return message(failure); }
    }

    @Override public void onMainActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode == PERMISSION_REQUEST) finishPermission();
        if (requestCode == INSTALL_REQUEST) {
            Uri uri = installedUri;
            installedUri = null;
            if (uri != null) getContext().revokeUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION);
            if (!destroyed) emitSignal("installer_returned");
        }
    }
    @Override public void onMainPause() { if (permissionPending.get()) permissionPaused = true; }
    @Override public void onMainResume() { if (permissionPaused && permissionPending.get()) finishPermission(); }
    @Override public void onGodotTerminating() { destroyed = true; verifier.shutdownNow(); }
    @Override public void onMainDestroy() { destroyed = true; verifier.shutdownNow(); }

    private static String result(boolean ok, String message) {
        try { return new JSONObject().put("ok", ok).put("message", message).toString(); }
        catch (Exception impossible) { return "{\"ok\":false,\"message\":\"Update verification failed.\"}"; }
    }
    private static String message(Exception failure) {
        Throwable detail = failure.getCause() != null ? failure.getCause() : failure;
        String value = detail.getMessage();
        return value == null || value.isEmpty() ? "Android could not complete the update request." : value;
    }
}
