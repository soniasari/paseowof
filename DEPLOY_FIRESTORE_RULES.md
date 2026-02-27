# Desplegar Reglas de Seguridad de Firestore

Este proyecto incluye reglas de seguridad de Firestore que aseguran que cada paseador solo pueda acceder a sus propios datos.

## Opción 1: Desde la Consola de Firebase (Recomendado)

1. Ve a [Firebase Console](https://console.firebase.google.com/)
2. Selecciona tu proyecto: **paseowof**
3. En el menú lateral, ve a **Firestore Database**
4. Haz clic en la pestaña **Reglas**
5. Copia el contenido del archivo `firestore.rules` (sin los comentarios finales)
6. Pega el contenido en el editor de reglas
7. Haz clic en **Publicar**

## Opción 2: Usando Firebase CLI

### Requisitos previos

1. Instala Node.js (si no lo tienes)
2. Instala Firebase CLI:
   ```bash
   npm install -g firebase-tools
   ```

### Pasos para desplegar

1. Inicia sesión en Firebase:
   ```bash
   firebase login
   ```

2. Inicializa Firebase en el proyecto (si no lo has hecho):
   ```bash
   firebase init firestore
   ```
   - Selecciona "Use an existing project"
   - Elige "paseowof"
   - Cuando pregunte por el archivo de reglas, confirma que es `firestore.rules`

3. Despliega las reglas:
   ```bash
   firebase deploy --only firestore:rules
   ```

## Verificación

Después de desplegar las reglas:

1. Ve a la consola de Firebase > Firestore Database > Reglas
2. Verifica que las reglas estén publicadas
3. Prueba con dos usuarios diferentes:
   - Usuario A solo debe ver sus propietarios y caninos
   - Usuario B solo debe ver sus propietarios y caninos
   - No deben poder ver los datos del otro

## ¿Qué protegen estas reglas?

- ✅ Solo el paseador autenticado puede leer/escribir su documento en `paseadores/{paseadorId}`
- ✅ Solo el paseador propietario puede acceder a sus `propietarios`
- ✅ Solo el paseador propietario puede acceder a sus `caninos`
- ✅ Solo el paseador propietario puede acceder a sus `paseos`
- ✅ Solo el paseador propietario puede acceder a sus `notificaciones`
- ✅ Solo el paseador propietario puede acceder a `paseos_caninos`
- ✅ Se deniega el acceso a cualquier otra colección

## Nota Importante

Las reglas están en el archivo `firestore.rules` en la raíz del proyecto. Este archivo debe estar en el control de versiones (Git) para mantener un historial de cambios.

