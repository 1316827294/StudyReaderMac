# StudyReaderMac

StudyReaderMac es una herramienta de estudio nativa para macOS diseñada específicamente para estudiantes y aprendices. Permite estudiar libros de texto en PDF o libros EPUB sin DRM de manera conveniente en su Mac sin la necesidad de libros físicos de papel.

## ¿Por qué StudyReaderMac?
El estudio tradicional a menudo requiere que hagas malabarismos entre libros físicos, cuadernos y materiales de referencia. StudyReaderMac simplifica esto al proporcionar una interfaz de doble panel:
- **Panel izquierdo (Lectura):** Lee directamente tus libros de texto en PDF o EPUB.
- **Panel derecho (Respuesta):** Escribe tus respuestas, notas o soluciones.
- **Verificación de IA:** Una vez que hayas respondido una pregunta, la aplicación captura tu vista de lectura actual y tu respuesta, y la envía a OpenAI (o API compatibles como DeepSeek/Ollama) para verificar tu exactitud y brindarte comentarios instantáneos.

Esto hace que estudiar y validar tus respuestas sea continuo, eficiente y completamente sin papel, perfecto para estudiantes que se preparan para exámenes o cualquier persona que esté aprendiendo temas nuevos.

## Características
- **Estudio sin papel:** Deshazte de los pesados libros de papel y cuadernos. Lee, responde y verifica todo dentro de una sola aplicación.
- **Comentarios instantáneos de IA:** Obtén correcciones y explicaciones inmediatas de la IA para tus respuestas escritas en función del contenido visible del libro de texto.
- **Desplazamiento continuo y sincronización:** El panel de lectura y tu hoja de respuestas se sincronizan automáticamente para no perder de vista tu lugar.
- **Múltiples proveedores de API:** Preconfigurado con OpenAI, DeepSeek y Ollama, o usa tu propio punto de enlace personalizado.
- **Soporte multilingüe:** Interfaz disponible en inglés, chino, japonés, coreano, español, francés y alemán.

## Ejecutar

```bash
swift run StudyReaderMac
```

## Empaquetar como aplicación macOS

```bash
sh Scripts/package-app.sh
open dist/StudyReaderMac.app
```

## Notas

- La aplicación no captura las ventanas de otras aplicaciones, por lo que no requiere el permiso de "Grabación de pantalla".
- Los archivos Kindle/Apple Books protegidos por DRM no son compatibles.
- El modelo predeterminado es `gpt-4o` (al usar OpenAI); cámbielo en Configuración si su cuenta de API requiere otro modelo.
