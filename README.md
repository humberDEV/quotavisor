# Quotavisor

Convierte el notch de tu Mac en una isla con el uso de **Claude Code** y **Codex**: cuánto te queda de la ventana de 5 horas y de la semanal, sin abrir nada.

- **Recogida:** anillo + % de la ventana de 5 h del proveedor que estés usando (o el que fijes).
- **Al pasar el ratón:** ambos proveedores, con su % de 5 h, cuándo se reinicia y el % semanal. Clic en una fila para fijarla en el notch.
- **Clic derecho:** actualizar ahora, qué mostrar, cada cuánto refrescar (1–30 min), abrir al iniciar sesión, salir.

Ligera: ≈55 MB de RAM y 0 % de CPU en reposo. Requiere macOS 14+ y Apple Silicon. Sin notch, se coloca bajo la barra de menús.

## Instalar

```bash
curl -fsSL https://quotavisor.vercel.app/install.sh | bash
```

Descarga el DMG de la [última release](https://github.com/humberDEV/quotavisor/releases/latest), copia la app a `/Applications` y la abre.

## Compilar tú mismo

```bash
./build.sh && open build/Quotavisor.app
```

`./install.sh` compila y la instala en `/Applications`; `./make-dmg.sh` genera `build/Quotavisor.dmg`.

## De dónde salen los datos

- **Claude Code:** `api.anthropic.com/api/oauth/usage`, con el token OAuth que Claude Code ya guarda en el Llavero (`Claude Code-credentials`). Solo lectura: nunca refresca ni modifica el token, y no lo envía a ningún otro sitio. La primera vez, macOS te pregunta si Quotavisor puede leerlo.
- **Codex:** los `rate_limits` de los registros locales en `~/.codex/sessions`. Sin red.

No hay servidores de Quotavisor ni analítica.

## Feedback

Escríbeme en X: [@humbergarc](https://x.com/humbergarc).

---

Quotavisor no está afiliada a Anthropic ni a OpenAI. Claude, Claude Code y Codex son marcas de sus respectivos dueños. Licencia [MIT](LICENSE).
