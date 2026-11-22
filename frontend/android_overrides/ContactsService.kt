package __PACKAGE__

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.ContactsContract
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Searches contacts and opens the dialer. It never places a call by itself. */
class ContactsService(private val ctx: Context) : NativeService {
    override val methods = setOf("contacts.search", "contacts.dial")

    override fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "contacts.dial") {
            val number = call.argument<String>("number") ?: ""
            if (number.isBlank()) {
                result.error("NO_NUMBER", "Phone number required", null)
                return
            }
            val intent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:" + Uri.encode(number)))
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            ctx.startActivity(intent)
            result.success(true)
            return
        }
        if (ctx.checkSelfPermission(Manifest.permission.READ_CONTACTS) != PackageManager.PERMISSION_GRANTED) {
            result.error("NO_PERMISSION", "Contacts permission is needed", null)
            return
        }
        val q = (call.argument<String>("query") ?: "").trim()
        val found = ArrayList<Map<String, String>>()
        val cursor = ctx.contentResolver.query(
            ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
            arrayOf(
                ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                ContactsContract.CommonDataKinds.Phone.NUMBER
            ),
            ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME + " LIKE ?",
            arrayOf("%$q%"),
            ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME + " ASC"
        )
        cursor?.use {
            while (it.moveToNext() && found.size < 8) {
                found.add(mapOf("name" to (it.getString(0) ?: ""), "number" to (it.getString(1) ?: "")))
            }
        }
        result.success(found)
    }
}
