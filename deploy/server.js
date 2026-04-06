// ════════════════════════════════════════════════════
// SOA Deploy Server
// Corre en el HOST (no en Docker) en puerto 3000
// ════════════════════════════════════════════════════
const express = require('express');
const fs = require('fs');
const path = require('path');
const app = express();
app.use(express.json({ limit: '10mb' }));

const SOA_OUTPUT = process.env.SOA_OUTPUT || '/home/laortiz937/soa/output';
const PORT = process.env.PORT || 3000;
const PUBLIC_URL = process.env.NGROK_URL || `http://localhost:${PORT}`;

// Servir archivos del output como estáticos — genera URL válida
app.use(express.static(SOA_OUTPUT));

app.post('/deploy', (req, res) => {
  const { archivo, contenido, ruta_destino, src, dst } = req.body;

  if (!archivo) {
    return res.status(400).json({
      ok: false, resultado: 'DEPLOY_ERROR', error: 'Falta el campo "archivo"'
    });
  }

  // Rutas Docker (/home/node/...) no existen en el host — ignorarlas siempre
  const esRutaDocker = (ruta_destino || '').startsWith('/home/node/') ||
                       (dst || '').startsWith('/home/node/');

  const dstPath = esRutaDocker
    ? path.join(SOA_OUTPUT, archivo)
    : (ruta_destino || dst || path.join(SOA_OUTPUT, archivo));

  const urlPublica = `${PUBLIC_URL}/${archivo}`;

  console.log(`📦 Deploy solicitado: ${archivo}`);
  console.log(`   destino: ${dstPath}`);
  console.log(`   url: ${urlPublica}`);
  console.log(`   modo: ${contenido !== undefined ? 'contenido directo' : 'copia desde src'}`);

  try {
    const dstDir = path.dirname(dstPath);
    if (!fs.existsSync(dstDir)) {
      fs.mkdirSync(dstDir, { recursive: true });
    }

    if (contenido !== undefined) {
      // n8n manda el contenido directo — escribir al disco
      fs.writeFileSync(dstPath, contenido, 'utf8');
    } else {
      // Fallback: copiar desde src (también ignorar rutas Docker)
      const srcRaw = src || path.join(SOA_OUTPUT, archivo);
      const srcPath = srcRaw.startsWith('/home/node/')
        ? path.join(SOA_OUTPUT, archivo)
        : srcRaw;

      console.log(`   src: ${srcPath}`);

      if (!fs.existsSync(srcPath)) {
        return res.status(404).json({
          ok: false, resultado: 'DEPLOY_ERROR',
          error: `Archivo no encontrado: ${srcPath}`
        });
      }
      fs.copyFileSync(srcPath, dstPath);
    }

    console.log(`✅ Deploy OK: ${archivo} → ${urlPublica}`);
    res.json({
      ok: true,
      resultado: 'DEPLOY_OK',
      mensaje: `Archivo ${archivo} desplegado correctamente`,
      archivo,
      nombre_archivo: archivo,
      destino: dstPath,
      url: urlPublica
    });

  } catch (err) {
    console.error(`❌ Deploy ERROR: ${err.message}`);
    res.status(500).json({
      ok: false, resultado: 'DEPLOY_ERROR', error: err.message
    });
  }
});

// Health check
app.get('/health', (req, res) => {
  res.json({
    ok: true,
    status: 'running',
    port: PORT,
    output: SOA_OUTPUT,
    public_url: PUBLIC_URL
  });
});

app.listen(PORT, () => {
  console.log(`🚀 Deploy server en http://localhost:${PORT}`);
  console.log(`   Archivos públicos: ${PUBLIC_URL}`);
  console.log(`   SOA_OUTPUT: ${SOA_OUTPUT}`);
});