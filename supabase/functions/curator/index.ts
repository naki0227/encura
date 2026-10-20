// EnCura: Gemini proxy (Supabase Edge Function)
//
// The app never holds the Gemini API key. It calls this function with the
// signed-in (anonymous) user's JWT, and this function calls Gemini with the
// key stored as a Supabase secret.
//
// Secrets (set with `supabase secrets set ...`, never commit the values):
//   GEMINI_API_KEY  required
//   GEMINI_MODEL    optional, defaults to DEFAULT_MODEL below
//
// Request body (JSON):
//   { "task": "chat", "message": string, "history"?: Turn[], "image"?: base64 }
//   { "task": "is_map", "image": base64 }
//   Turn = { "role": "user" | "model", "text": string }
//
// Response body (JSON):
//   chat   -> { "text": string }
//   is_map -> { "is_map": boolean }
//   error  -> { "error": string }

const GEMINI_ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/models";
const DEFAULT_MODEL = "gemini-3.8-flash";

// Keep the last 20 turns (user + model) as the spec says.
const MAX_HISTORY_CONTENTS = 40;
const MAX_MESSAGE_CHARS = 4000;
const MAX_IMAGE_BASE64_CHARS = 8 * 1024 * 1024;

const CURATOR_INSTRUCTION = `
あなたは「EnCura（エンキュラ）」、プロフェッショナルなAI専属学芸員です。
あなたの役割は、芸術、歴史、文化、美術館、そしてアーティストの伝記について深い洞察を提供することです。

**厳格なドメイン制御:**
- あなたは、芸術、歴史、文化、美術館、アーティストの伝記に関連する質問にのみ答える必要があります。
- ユーザーがそれ以外の話題（例：天気、日常会話、人生相談、プログラミング、数学など）について尋ねた場合、「私はアートの専門家ですので、その話題についてはお答えできません」と丁寧に断ってください。
- **常に日本語で応答してください。**
- プロの学芸員のように、丁寧で知識豊富、かつ魅力的な口調を維持してください。
`;

const MAP_CHECK_PROMPT =
  'Is this image a map, floor plan, or venue guide? Respond with JSON: {"is_map": true/false}';

type Turn = { role: "user" | "model"; text: string };
type Part = { text: string } | { inline_data: { mime_type: string; data: string } };
type Content = { role: "user" | "model"; parts: Part[] };

class BadRequest extends Error {}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function imagePart(image: unknown): Part {
  if (typeof image !== "string" || image.length === 0) {
    throw new BadRequest("image must be a base64 string");
  }
  if (image.length > MAX_IMAGE_BASE64_CHARS) {
    throw new BadRequest("image is too large");
  }
  return { inline_data: { mime_type: "image/jpeg", data: image } };
}

function historyContents(history: unknown): Content[] {
  if (history == null) return [];
  if (!Array.isArray(history)) throw new BadRequest("history must be an array");
  return history
    .filter((t): t is Turn =>
      t != null &&
      (t.role === "user" || t.role === "model") &&
      typeof t.text === "string" &&
      t.text.length > 0
    )
    .slice(-MAX_HISTORY_CONTENTS)
    .map((t) => ({
      role: t.role,
      parts: [{ text: t.text.slice(0, MAX_MESSAGE_CHARS) }],
    }));
}

async function callGemini(payload: Record<string, unknown>): Promise<string> {
  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) throw new Error("GEMINI_API_KEY is not set");
  const model = Deno.env.get("GEMINI_MODEL") || DEFAULT_MODEL;

  const res = await fetch(`${GEMINI_ENDPOINT}/${model}:generateContent`, {
    method: "POST",
    headers: { "Content-Type": "application/json", "x-goog-api-key": apiKey },
    body: JSON.stringify(payload),
  });
  if (!res.ok) {
    // Log the upstream error for the owner; do not echo it to the client.
    console.error(`Gemini ${model} returned ${res.status}: ${await res.text()}`);
    throw new Error(`Gemini request failed (${res.status})`);
  }
  const data = await res.json();
  const parts = data?.candidates?.[0]?.content?.parts ?? [];
  return parts
    .map((p: { text?: string }) => p.text ?? "")
    .join("")
    .trim();
}

async function chat(body: Record<string, unknown>): Promise<Response> {
  const message = body.message;
  if (typeof message !== "string" || message.trim().length === 0) {
    throw new BadRequest("message is required");
  }
  const parts: Part[] = [{ text: message.slice(0, MAX_MESSAGE_CHARS) }];
  if (body.image != null) parts.push(imagePart(body.image));

  const text = await callGemini({
    system_instruction: { parts: [{ text: CURATOR_INSTRUCTION }] },
    contents: [...historyContents(body.history), { role: "user", parts }],
  });
  return json({ text });
}

async function isMap(body: Record<string, unknown>): Promise<Response> {
  const text = await callGemini({
    contents: [{ role: "user", parts: [{ text: MAP_CHECK_PROMPT }, imagePart(body.image)] }],
    generationConfig: { responseMimeType: "application/json" },
  });
  let result = false;
  try {
    result = JSON.parse(text)?.is_map === true;
  } catch {
    console.error(`Unexpected map check response: ${text}`);
  }
  return json({ is_map: result });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid JSON" }, 400);
  }

  try {
    switch (body.task) {
      case "chat":
        return await chat(body);
      case "is_map":
        return await isMap(body);
      default:
        return json({ error: "unknown task" }, 400);
    }
  } catch (e) {
    if (e instanceof BadRequest) return json({ error: e.message }, 400);
    console.error(e);
    return json({ error: "upstream error" }, 502);
  }
});
