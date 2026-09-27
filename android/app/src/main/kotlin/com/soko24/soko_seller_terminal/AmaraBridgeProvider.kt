package com.soko24.soko_seller_terminal

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri

/** Public discovery only. No shop rows, files, credentials or database handles leave Terminal.
 * Business reads use Amara's authenticated seller-scoped server bridge. Terminal owns
 * its offline Drift database and all writes continue through its normal sync workflows.
 */
class AmaraBridgeProvider : ContentProvider() {
    override fun onCreate() = true
    override fun call(method: String, arg: String?, extras: android.os.Bundle?): android.os.Bundle {
        require(callingPackage == "co.sanaa.agent") { "Only Amara may request shop verification" }
        require(method == "refresh_identity" && arg == null && extras == null) { "Unsupported bridge request" }
        return android.os.Bundle().apply { putBoolean("refreshed", MainActivity.refreshAmaraIdentity()) }
    }
    override fun getType(uri: Uri): String? = if (uri.path == "/context")
        "vnd.android.cursor.item/vnd.soko24.amara-context" else null

    override fun query(uri: Uri, projection: Array<out String>?, selection: String?,
        selectionArgs: Array<out String>?, sortOrder: String?): Cursor {
        require(uri.path in setOf("/context", "/identity") && uri.query == null) { "Unsupported bridge resource" }
        require(selection == null && selectionArgs == null && sortOrder == null) { "Discovery does not accept SQL" }
        if (uri.path == "/identity") {
            require(callingPackage == "co.sanaa.agent") { "Identity is available only to installed Amara" }
            require(projection == null || projection.toList() == listOf("assertion")) { "Unknown identity field" }
            val assertion = requireNotNull(context).getSharedPreferences("amara_identity", android.content.Context.MODE_PRIVATE).getString("assertion", "").orEmpty()
            return MatrixCursor(arrayOf("assertion")).apply { addRow(arrayOf(assertion)) }
        }
        val values = linkedMapOf<String, Any>(
            "protocol_version" to 2,
            "package_name" to requireNotNull(context).packageName,
            "database_name" to "seller_terminal.db",
            "database_access" to "terminal_private",
            "business_data_access" to "authenticated_seller_scoped_backend",
            "media_exchange" to "owner_selected_document_tree",
            "offline_first" to 1,
        )
        val columns = projection?.toList() ?: values.keys.toList()
        require(columns.all { it in values }) { "Unknown discovery field" }
        return MatrixCursor(columns.toTypedArray()).apply { addRow(columns.map { values[it] }) }
    }
    override fun insert(uri: Uri, values: ContentValues?): Uri = throw UnsupportedOperationException("Discovery only")
    override fun update(uri: Uri, values: ContentValues?, selection: String?, selectionArgs: Array<out String>?) =
        throw UnsupportedOperationException("Discovery only")
    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?) =
        throw UnsupportedOperationException("Discovery only")
}
