import { httpRouter } from "convex/server";
import { internal } from "./_generated/api";
import { httpAction } from "./_generated/server";

const http = httpRouter();

/** Set as the App Store Server Notifications V2 URL (production and sandbox) in App Store Connect. */
http.route({
  path: "/appstore/notifications",
  method: "POST",
  handler: httpAction(async (ctx, req) => {
    let body: unknown;
    try {
      body = await req.json();
    } catch {
      return new Response("Invalid JSON", { status: 400 });
    }
    const signedPayload =
      typeof body === "object" && body !== null ? (body as Record<string, unknown>).signedPayload : undefined;
    if (typeof signedPayload !== "string") {
      return new Response("Missing signedPayload", { status: 400 });
    }
    const result = await ctx.runAction(internal.appStore.processNotification, { signedPayload });
    return new Response(result, { status: result === "invalid" ? 400 : 200 });
  }),
});

export default http;
