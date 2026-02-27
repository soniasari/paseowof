# Comparación de Reglas de Seguridad de Firestore

Este documento te ayudará a comparar las reglas existentes con las nuevas y decidir si reemplazarlas o fusionarlas.

## 📋 Instrucciones

1. **Ve a Firebase Console** → Firestore Database → Reglas
2. **Copia las reglas actuales** que tienes publicadas
3. **Compáralas** con las nuevas reglas en este documento
4. **Decide** si reemplazar o fusionar

---

## 🔒 Nuevas Reglas Propuestas

Las nuevas reglas están en `firestore.rules` y protegen:

```javascript
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper function para verificar que el usuario está autenticado
    function isAuthenticated() {
      return request.auth != null;
    }
    
    // Helper function para verificar que el paseadorId coincide con el usuario autenticado
    function isOwner(paseadorId) {
      return isAuthenticated() && request.auth.uid == paseadorId;
    }
    
    // Reglas para la colección de paseadores
    match /paseadores/{paseadorId} {
      // Solo el propietario puede leer y escribir su propio documento de paseador
      allow read, write: if isOwner(paseadorId);
      
      // Subcolección de propietarios
      match /propietarios/{propietarioId} {
        allow read, write: if isOwner(paseadorId);
      }
      
      // Subcolección de caninos
      match /caninos/{caninoId} {
        allow read, write: if isOwner(paseadorId);
      }
      
      // Subcolección de paseos
      match /paseos/{paseoId} {
        allow read, write: if isOwner(paseadorId);
        
        // Subcolección de paseos_caninos
        match /paseos_caninos/{paseoCaninoId} {
          allow read, write: if isOwner(paseadorId);
        }
      }
      
      // Subcolección de notificaciones
      match /notificaciones/{notificacionId} {
        allow read, write: if isOwner(paseadorId);
      }
    }
    
    // Denegar acceso a cualquier otra colección
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

---

## ✅ Características de las Nuevas Reglas

- ✅ **Autenticación requerida**: Solo usuarios autenticados pueden acceder
- ✅ **Aislamiento por usuario**: Cada paseador solo accede a sus datos (`paseadorId == request.auth.uid`)
- ✅ **Protección completa**: Todas las subcolecciones están protegidas
- ✅ **Denegación por defecto**: Cualquier otra colección está bloqueada
- ✅ **Funciones helper**: Código más limpio y mantenible

---

## 🔍 Qué Verificar en tus Reglas Actuales

### 1. ¿Tienes reglas para `paseadores`?
   - ✅ Sí → Compara si son similares
   - ❌ No → Debes agregarlas

### 2. ¿Protegen las subcolecciones?
   - `propietarios`
   - `caninos`
   - `paseos`
   - `paseos_caninos`
   - `notificaciones`

### 3. ¿Verifican que `paseadorId == request.auth.uid`?
   - Esta es la regla más importante para el aislamiento de datos

### 4. ¿Tienes reglas adicionales que necesites mantener?
   - Por ejemplo: reglas para colecciones de administradores
   - Reglas para datos públicos
   - Reglas especiales para ciertos documentos

---

## 📝 Plantilla para Comparar

Copia tus reglas actuales aquí y compara:

### Reglas Actuales:
```
[Pega aquí tus reglas actuales de Firebase Console]
```

### Diferencias Encontradas:
- [ ] Reglas idénticas → No necesitas cambiar nada
- [ ] Reglas similares pero con diferencias menores → Puedes fusionar
- [ ] Reglas muy diferentes → Necesitas revisar caso por caso
- [ ] No tienes reglas → Debes implementar las nuevas

---

## 🎯 Recomendaciones

### Si tus reglas actuales son:
1. **Similares o idénticas** → No necesitas cambiar nada, las nuevas son solo una versión documentada
2. **Más permisivas** → Reemplázalas con las nuevas para mayor seguridad
3. **Más restrictivas** → Revisa si necesitas mantener alguna restricción adicional
4. **No existen o están vacías** → Implementa las nuevas reglas inmediatamente

---

## ⚠️ Importante Antes de Reemplazar

1. **Haz una copia de seguridad** de tus reglas actuales
2. **Prueba en modo de prueba** si Firebase lo permite
3. **Verifica** que no tengas usuarios o procesos que dependan de reglas más permisivas
4. **Despliega en horario de bajo tráfico** si es posible

---

## 📞 Siguiente Paso

Una vez que compares, puedes:

1. **Reemplazar completamente** si las nuevas son mejores
2. **Fusionar** si necesitas mantener algunas reglas existentes
3. **Mantener las actuales** si ya están bien implementadas

¿Necesitas ayuda para fusionar reglas específicas? Comparte tus reglas actuales y te ayudo a crear una versión combinada.

