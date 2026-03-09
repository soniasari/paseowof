Paseowof – Cómo ejecutar el proyecto
------------------------------------
Requisitos previos
------------------
Flutter SDK (3.x, compatible con sdk: ^3.9.2 del proyecto).
	Instalación: https://docs.flutter.dev/get-started/install
	Comprueba con: flutter doctor
Git
Para Android: Android Studio o SDK de Android + un emulador o dispositivo con depuración USB.
Para iOS: Xcode (solo en Mac).
Cuenta de Firebase (para Auth y Firestore).

Pasos para ejecutar en local
----------------------------
1. Clonar el repositorio
git clone <https://github.com/soniasari/paseowof>
cd paseowof

2. Instalar dependencias
flutter pub get

3. Configurar Firebase
La app usa Firebase (Auth, Firestore). Para que funcione en un equipo:

Opción A – El repositorio ya incluye la configuración
	Si en el repositorio están android/app/google-services.json y lib/firebase_options.dart, no hace falta hacer nada más. Pasa al paso 4.

Opción B – Usas tu propio proyecto de Firebase
	1. Entra en Firebase Console y crea un proyecto (o usa uno existente).
	2. Añade una app Android (y/o iOS si vas a probar en iOS).
	3. Descarga google-services.json y colócalo en android/app/google-services.json.
	4. Para Firebase Options en Flutter, ejecuta en la raíz del proyecto:
		flutterfire configure

(Necesitas la CLI de FlutterFire: dart pub global activate flutterfire_cli).
Eso generará o actualizará lib/firebase_options.dart con las claves del proyecto.

Activa en la consola de Firebase: Authentication (correo/contraseña si usas login con email) y Cloud Firestore.

4. Comprobar el entorno
	flutter doctor
	Corrige cualquier error que indique (licencias de Android, Xcode, etc.).

5. Ejecutar la aplicación
	En un emulador o dispositivo conectado (por defecto):
	flutter run
	Elegir dispositivo si tienes varios:
		flutter devices
		flutter run -d <id-del-dispositivo>
	En Chrome (web):
		flutter run -d chrome
		
La primera vez puede tardar más mientras se descargan dependencias y se compila.

Resumen rápido
Clonar repo → cd paseowof
flutter pub get
Tener configurado Firebase (google-services.json + firebase_options.dart)
flutter doctor (opcional pero recomendado)
flutter run
Problemas frecuentes
“No se encuentra google-services.json” → Sigue la Opción B del paso 3 y coloca el archivo en android/app/.
“Firebase not configured” / errores de inicialización → Asegúrate de que lib/firebase_options.dart existe y corresponde al mismo proyecto que google-services.json.
Errores de permisos (ubicación, notificaciones) → En dispositivo/emulador, conceder los permisos que pida la app cuando los solicite.
