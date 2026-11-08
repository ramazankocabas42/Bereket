"""`flutter create` ile oluşan Android dosyalarını uygulamaya göre ayarlar.

- Uygulama adı "Bereket"
- İnternet, bildirim ve uygulama içi güncelleme izinleri
- minSdk 24, Java 17
- Sabit imza: BEREKET_KEYSTORE_PASSWORD tanımlıysa ci/bereket.p12 ile
  imzalanır; böylece yeni sürüm eskisinin üzerine kurulabilir.

Birden fazla çalıştırılsa da aynı sonucu verir.
"""
import os
import re
import sys

KOK = sys.argv[1] if len(sys.argv) > 1 else "."
APP = os.path.join(KOK, "android", "app")
MANIFEST = os.path.join(APP, "src", "main", "AndroidManifest.xml")


def oku(p):
    with open(p, encoding="utf-8") as f:
        return f.read()


def yaz(p, s):
    with open(p, "w", encoding="utf-8") as f:
        f.write(s)


# --- AndroidManifest.xml ---------------------------------------------------
m = oku(MANIFEST)
m = re.sub(r'android:label="[^"]*"', 'android:label="Bereket"', m, count=1)

izinler = [
    "android.permission.INTERNET",
    "android.permission.REQUEST_INSTALL_PACKAGES",
    "android.permission.POST_NOTIFICATIONS",
]
eklenecek = "".join(
    f'    <uses-permission android:name="{i}"/>\n' for i in izinler if i not in m
)
if "WRITE_EXTERNAL_STORAGE" not in m:
    eklenecek += '    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="28"/>\n'
if eklenecek:
    m = re.sub(r"(<manifest[^>]*>\n)", lambda x: x.group(1) + eklenecek, m, count=1)

if "OtaUpdateFileProvider" not in m:
    ota = """        <provider
            android:name="sk.fourq.otaupdate.OtaUpdateFileProvider"
            android:authorities="${applicationId}.ota_update_provider"
            android:exported="false"
            android:grantUriPermissions="true">
            <meta-data
                android:name="android.support.FILE_PROVIDER_PATHS"
                android:resource="@xml/filepaths" />
        </provider>
        <receiver android:name="sk.fourq.otaupdate.InstallResultReceiver" android:exported="false">
            <intent-filter>
                <action android:name="${applicationId}.ACTION_INSTALL_COMPLETE"/>
            </intent-filter>
        </receiver>
"""
    m = m.replace("    </application>", ota + "    </application>", 1)
# Tarayıcıda bağlantı açabilmek için (Türkşeker, e-Devlet sayfaları).
GORUNUM = """        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="https" />
        </intent>
"""
if 'android:scheme="https"' not in m:
    if "<queries>" in m:
        m = m.replace("<queries>\n", "<queries>\n" + GORUNUM, 1)
    else:
        m = m.replace("</manifest>", "    <queries>\n" + GORUNUM + "    </queries>\n</manifest>", 1)
yaz(MANIFEST, m)

xml_klasor = os.path.join(APP, "src", "main", "res", "xml")
os.makedirs(xml_klasor, exist_ok=True)
yaz(os.path.join(xml_klasor, "filepaths.xml"), """<?xml version="1.0" encoding="utf-8"?>
<paths xmlns:android="http://schemas.android.com/apk/res/android">
    <files-path name="internal_apk_storage" path="ota_update/"/>
</paths>
""")

# --- build.gradle(.kts) ----------------------------------------------------
kts = os.path.join(APP, "build.gradle.kts")
groovy = os.path.join(APP, "build.gradle")
if os.path.exists(kts):
    p, kotlin_dsl = kts, True
elif os.path.exists(groovy):
    p, kotlin_dsl = groovy, False
else:
    sys.exit("android/app/build.gradle bulunamadı")

g = oku(p)
g = re.sub(r"minSdk(Version)?\s*=?\s*flutter\.minSdkVersion", "minSdk = 24", g)
g = g.replace("VERSION_1_8", "VERSION_17").replace("VERSION_11", "VERSION_17")
g = g.replace("JVM_1_8", "JVM_17").replace("JVM_11", "JVM_17")
g = re.sub(r"jvmTarget\s*=\s*['\"](1\.8|11)['\"]", 'jvmTarget = "17"', g)

# ota_update paketi core library desugaring ister.
DESUGAR = "com.android.tools:desugar_jdk_libs:2.1.5"
if "CoreLibraryDesugaringEnabled" not in g and "coreLibraryDesugaringEnabled" not in g:
    satir = (
        "isCoreLibraryDesugaringEnabled = true"
        if kotlin_dsl
        else "coreLibraryDesugaringEnabled true"
    )
    if "compileOptions {" not in g:
        sys.exit("compileOptions bloğu bulunamadı")
    g = g.replace("compileOptions {", "compileOptions {\n        " + satir, 1)
if "desugar_jdk_libs" not in g:
    bagimlilik = (
        f'    coreLibraryDesugaring("{DESUGAR}")'
        if kotlin_dsl
        else f"    coreLibraryDesugaring '{DESUGAR}'"
    )
    g = g.rstrip() + "\n\ndependencies {\n" + bagimlilik + "\n}\n"

if "bereket.p12" not in g:
    if kotlin_dsl:
        imza = """    signingConfigs {
        getByName("debug") {
            val sifre = System.getenv("BEREKET_KEYSTORE_PASSWORD")
            if (!sifre.isNullOrEmpty()) {
                storeFile = file("../../ci/bereket.p12")
                storeType = "PKCS12"
                storePassword = sifre
                keyAlias = "tarlam"
                keyPassword = sifre
            }
        }
    }
"""
    else:
        imza = """    signingConfigs {
        debug {
            def sifre = System.getenv("BEREKET_KEYSTORE_PASSWORD")
            if (sifre) {
                storeFile file('../../ci/bereket.p12')
                storeType 'PKCS12'
                storePassword sifre
                keyAlias 'tarlam'
                keyPassword sifre
            }
        }
    }
"""
    g, n = re.subn(r"(\nandroid \{\n)", lambda x: x.group(1) + imza, g, count=1)
    if n != 1:
        sys.exit("android { bloğu bulunamadı")
yaz(p, g)
print("Android ayarları uygulandı:", p)
