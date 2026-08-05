# 📘 Guía de Desarrollo, Subida de Cambios y Generación de APK

Esta guía explica el flujo de trabajo para modificar la aplicación **ATM - Test de Fonseca**, subir las actualizaciones a GitHub y obtener automáticamente el archivo **APK** listo para instalar en cualquier celular Android.

---

## ⚡ 1. El Comando Mágico (1 sola línea)

Cada vez que realicemos cambios en el código y desees generar la versión actualizada del APK en la nube, ejecuta esta línea en la terminal de Android Studio:

```powershell
git add . ; git commit -m "Actualización del proyecto" ; & "C:\src\flutter\bin\mingit\cmd\git.exe" push origin main
```

*(Si la terminal te solicita nombre de usuario y contraseña, ingresa tu usuario `LudinSanz` y tu Token de GitHub `ghp_...`)*.

---

## 🔄 2. Flujo de Trabajo Paso a Paso

### **Paso A: Programar los cambios aquí**
1. Pídele al asistente de inteligencia artificial cualquier cambio en el chat *(ejemplo: "Cambia el color del botón principal", "Agrega una nueva pregunta al Test", "Modifica la pantalla de perfil")*.
2. El asistente editará los archivos y probará la sintaxis aquí en tu computadora.

### **Paso B: Subir los cambios a GitHub**
1. Abre la pestaña **Terminal** en la parte inferior de Android Studio.
2. Ejecuta el **Comando Mágico** mostrado en la Sección 1.

### **Paso C: Compilación automática en la nube**
1. Al hacer el `push`, los servidores de GitHub iniciarán la compilación del APK automáticamente.
2. Puedes ver el avance en vivo en:
   👉 **[github.com/LudinSanz/test_de_fonseca/actions](https://github.com/LudinSanz/test_de_fonseca/actions)**

### **Paso D: Descargar e instalar en tu celular Android**
1. En 2 o 3 minutos, la compilación finalizará con éxito.
2. Abre esta dirección en el navegador de cualquier celular Android:
   👉 **[github.com/LudinSanz/test_de_fonseca/releases](https://github.com/LudinSanz/test_de_fonseca/releases)**
3. Toca la versión más reciente (ej. `v1.0.2`), descarga el archivo `app-release.apk` e instálalo en tu celular.

---

## 🔑 3. Datos y Accesos Importantes

* **Repositorio en GitHub**: [https://github.com/LudinSanz/test_de_fonseca](https://github.com/LudinSanz/test_de_fonseca)
* **Base de Datos & Auth (Supabase)**:
  - **URL**: `https://eadmcexipsdytyjbwgis.supabase.co`
  - **Clave**: `sb_publishable_9xS9DlltcsHSd7qGlnKDOg_-J_ziCMK`
* **Compilado local previo**: `C:\Users\Ludin Solis\Desktop\test_de_fonseca\test_de_fonseca\build\app\outputs\flutter-apk\app-release.apk`
