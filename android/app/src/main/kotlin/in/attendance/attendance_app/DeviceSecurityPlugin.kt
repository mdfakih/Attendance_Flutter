package `in`.attendance.attendance_app

import android.content.Context
import android.os.Build
import android.provider.Settings
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.security.keystore.StrongBoxUnavailableException
import android.util.Base64
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.PrivateKey
import java.security.PublicKey
import java.security.Signature
import java.security.spec.ECGenParameterSpec

/**
 * Hardware-backed P-256 device key. The private key never leaves the Android Keystore; the app
 * only receives the public key (SPKI DER) and signatures (DER) over server-provided messages.
 */
class DeviceSecurityPlugin(private val context: Context) : MethodChannel.MethodCallHandler {
  companion object {
    const val CHANNEL = "attendance/device_security"
    private const val KEYSTORE = "AndroidKeyStore"
    private const val ALIAS = "attn_device_v1"
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    try {
      when (call.method) {
        "hasKey" -> result.success(loadKeyStore().containsAlias(ALIAS))
        "generateKey" -> result.success(generateKey())
        "getPublicKey" -> result.success(publicKey()?.let { Base64.encodeToString(it.encoded, Base64.NO_WRAP) })
        "sign" -> {
          val message = call.argument<String>("message") ?: throw IllegalArgumentException("message required")
          result.success(sign(message))
        }
        "deleteKey" -> {
          loadKeyStore().deleteEntry(ALIAS)
          result.success(true)
        }
        "androidId" -> result.success(Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID))
        "securityLevel" -> result.success(securityLevel())
        else -> result.notImplemented()
      }
    } catch (e: Exception) {
      result.error("DEVICE_SECURITY", e.message, null)
    }
  }

  private fun loadKeyStore(): KeyStore = KeyStore.getInstance(KEYSTORE).apply { load(null) }

  /** Creates (or replaces) the key. Tries StrongBox first, then the TEE. Returns base64 SPKI. */
  private fun generateKey(): String {
    val keyStore = loadKeyStore()
    if (keyStore.containsAlias(ALIAS)) keyStore.deleteEntry(ALIAS)
    val spec = { strongBox: Boolean ->
      KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY)
        .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
        .setDigests(KeyProperties.DIGEST_SHA256)
        .apply { if (strongBox && Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) setIsStrongBoxBacked(true) }
        .build()
    }
    val generator = KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_EC, KEYSTORE)
    val pair = try {
      generator.initialize(spec(true))
      generator.generateKeyPair()
    } catch (e: StrongBoxUnavailableException) {
      generator.initialize(spec(false))
      generator.generateKeyPair()
    } catch (e: Exception) {
      generator.initialize(spec(false))
      generator.generateKeyPair()
    }
    return Base64.encodeToString(pair.public.encoded, Base64.NO_WRAP)
  }

  private fun publicKey(): PublicKey? = loadKeyStore().getCertificate(ALIAS)?.publicKey

  private fun sign(message: String): String {
    val key = loadKeyStore().getKey(ALIAS, null) as? PrivateKey ?: throw IllegalStateException("No device key")
    val signature = Signature.getInstance("SHA256withECDSA").apply {
      initSign(key)
      update(message.toByteArray(Charsets.UTF_8))
    }
    return Base64.encodeToString(signature.sign(), Base64.NO_WRAP)
  }

  private fun securityLevel(): String {
    if (!loadKeyStore().containsAlias(ALIAS)) return "NONE"
    return try {
      val key = loadKeyStore().getKey(ALIAS, null) as PrivateKey
      val factory = java.security.KeyFactory.getInstance(key.algorithm, KEYSTORE)
      val info = factory.getKeySpec(key, android.security.keystore.KeyInfo::class.java)
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        when (info.securityLevel) {
          KeyProperties.SECURITY_LEVEL_STRONGBOX -> "STRONGBOX"
          KeyProperties.SECURITY_LEVEL_TRUSTED_ENVIRONMENT -> "TEE"
          else -> "SOFTWARE"
        }
      } else {
        @Suppress("DEPRECATION")
        if (info.isInsideSecureHardware) "TEE" else "SOFTWARE"
      }
    } catch (e: Exception) {
      "UNKNOWN"
    }
  }
}
