import {
  customMutation,
  customQuery,
} from "convex-helpers/server/customFunctions";
import { mutation, query } from "../_generated/server";
import { requireUser } from "./auth";

export const authedQuery = customQuery(query, {
  args: {},
  input: async (ctx) => {
    const user = await requireUser(ctx);
    return { ctx: { ...ctx, user }, args: {} };
  },
});

export const authedMutation = customMutation(mutation, {
  args: {},
  input: async (ctx) => {
    const user = await requireUser(ctx);
    return { ctx: { ...ctx, user }, args: {} };
  },
});
