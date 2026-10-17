package com.bobc.formulariosalida;

import android.content.ContentProvider;
import android.content.ContentValues;
import android.database.Cursor;
import android.database.MatrixCursor;
import android.net.Uri;
import android.os.ParcelFileDescriptor;
import android.provider.OpenableColumns;

import java.io.File;
import java.io.FileNotFoundException;

/** Provider de solo lectura: comparte únicamente archivos generados en el caché de la aplicación. */
public final class SharedFileProvider extends ContentProvider {
    private File locate(Uri uri) throws FileNotFoundException {
        String filename = uri.getLastPathSegment();
        if (filename == null || !filename.matches("[a-zA-Z0-9_.-]{1,110}\\.(pdf|docx|xlsx)"))
            throw new FileNotFoundException("Archivo no permitido.");
        File file = new File(new File(getContext().getCacheDir(), "compartidos"), filename);
        if (!file.isFile()) throw new FileNotFoundException("Archivo no encontrado.");
        return file;
    }
    @Override public boolean onCreate() { return true; }
    @Override public String getType(Uri uri) {
        String path = uri.getLastPathSegment();
        if (path != null && path.endsWith(".pdf")) return "application/pdf";
        if (path != null && path.endsWith(".docx")) return "application/vnd.openxmlformats-officedocument.wordprocessingml.document";
        if (path != null && path.endsWith(".xlsx")) return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
        return "application/octet-stream";
    }
    @Override public ParcelFileDescriptor openFile(Uri uri, String mode) throws FileNotFoundException {
        if (!"r".equals(mode)) throw new FileNotFoundException("Solo lectura.");
        return ParcelFileDescriptor.open(locate(uri), ParcelFileDescriptor.MODE_READ_ONLY);
    }
    @Override public Cursor query(Uri uri, String[] projection, String selection, String[] selectionArgs, String sortOrder) {
        try {
            File file=locate(uri);
            String[] cols=projection==null?new String[]{OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE}:projection;
            MatrixCursor out = new MatrixCursor(cols);
            Object[] values = new Object[cols.length];
            for(int i=0;i<cols.length;i++) {
                if(OpenableColumns.DISPLAY_NAME.equals(cols[i])) values[i]=file.getName();
                else if(OpenableColumns.SIZE.equals(cols[i])) values[i]=file.length();
            }
            out.addRow(values);return out;
        } catch(FileNotFoundException e){return new MatrixCursor(projection == null ? new String[] {OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE} : projection);}
    }
    @Override public Uri insert(Uri uri, ContentValues values) {throw new UnsupportedOperationException("Solo lectura.");}
    @Override public int update(Uri uri, ContentValues values, String where, String[] args) {throw new UnsupportedOperationException("Solo lectura.");}
    @Override public int delete(Uri uri, String where, String[] args) {throw new UnsupportedOperationException("Solo lectura.");}
}
