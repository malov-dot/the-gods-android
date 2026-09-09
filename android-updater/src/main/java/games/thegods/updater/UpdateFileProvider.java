package games.thegods.updater;

import android.database.Cursor;
import android.net.Uri;
import android.os.ParcelFileDescriptor;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.core.content.FileProvider;
import java.io.FileNotFoundException;

/** Exposes only the one update APK, and only through a temporary read grant. */
public final class UpdateFileProvider extends FileProvider {
    private void requireUpdateUri(Uri uri) {
        if (!"/updates/update.apk".equals(uri.getEncodedPath()) || uri.getQuery() != null)
            throw new SecurityException("Only the update APK may be shared.");
    }
    @Override public ParcelFileDescriptor openFile(@NonNull Uri uri, @NonNull String mode) throws FileNotFoundException {
        requireUpdateUri(uri);
        if (!"r".equals(mode)) throw new SecurityException("The update APK is read-only.");
        return super.openFile(uri, mode);
    }
    @Override public Cursor query(@NonNull Uri uri, @Nullable String[] projection, @Nullable String selection,
            @Nullable String[] selectionArgs, @Nullable String sortOrder) {
        requireUpdateUri(uri);
        return super.query(uri, projection, selection, selectionArgs, sortOrder);
    }
    @Override public String getType(@NonNull Uri uri) { requireUpdateUri(uri); return "application/vnd.android.package-archive"; }
    @Override public int delete(@NonNull Uri uri, @Nullable String selection, @Nullable String[] selectionArgs) {
        throw new SecurityException("The update APK is read-only.");
    }
}
