// Stores the email in Redis (hash "downloads": email -> first signup date) and returns the download link.
const DOWNLOAD_URL = "https://github.com/martinmana808/winamp-ish/releases/download/v1.0.0/Winamp-ish.zip";

module.exports = async (req, res) => {
  if (req.method !== "POST") {
    res.setHeader("Allow", "POST");
    return res.status(405).json({ error: "Método no permitido" });
  }

  const email = String(req.body?.email ?? "").trim().toLowerCase();
  if (email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email)) {
    return res.status(400).json({ error: "Ese email no parece válido" });
  }

  const saved = await fetch(process.env.KV_REST_API_URL, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${process.env.KV_REST_API_TOKEN}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(["HSETNX", "downloads", email, new Date().toISOString()]),
  });
  if (!saved.ok) {
    console.error("Redis error", saved.status, await saved.text());
    return res.status(500).json({ error: "No pudimos guardar tu email. Probá de nuevo." });
  }

  return res.status(200).json({ url: DOWNLOAD_URL });
};
