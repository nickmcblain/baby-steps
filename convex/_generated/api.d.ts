/* eslint-disable */
/**
 * Generated `api` utility.
 *
 * THIS CODE IS AUTOMATICALLY GENERATED.
 *
 * To regenerate, run `npx convex dev`.
 * @module
 */

import type * as account from "../account.js";
import type * as allowance from "../allowance.js";
import type * as appStore from "../appStore.js";
import type * as babies from "../babies.js";
import type * as careExport from "../careExport.js";
import type * as chat from "../chat.js";
import type * as chatAgent from "../chatAgent.js";
import type * as events from "../events.js";
import type * as guidance_corpus from "../guidance/corpus.js";
import type * as http from "../http.js";
import type * as lib_access from "../lib/access.js";
import type * as lib_allowance from "../lib/allowance.js";
import type * as lib_allowanceDb from "../lib/allowanceDb.js";
import type * as lib_appleRootCa from "../lib/appleRootCa.js";
import type * as lib_appStore from "../lib/appStore.js";
import type * as lib_auth from "../lib/auth.js";
import type * as lib_babyContext from "../lib/babyContext.js";
import type * as lib_clothingAdvice from "../lib/clothingAdvice.js";
import type * as lib_functions from "../lib/functions.js";
import type * as lib_logEvents from "../lib/logEvents.js";
import type * as lib_sharing from "../lib/sharing.js";
import type * as lib_validators from "../lib/validators.js";
import type * as subscriptions from "../subscriptions.js";
import type * as users from "../users.js";
import type * as voiceLog from "../voiceLog.js";
import type * as voiceTools from "../voiceTools.js";

import type {
  ApiFromModules,
  FilterApi,
  FunctionReference,
} from "convex/server";

declare const fullApi: ApiFromModules<{
  account: typeof account;
  allowance: typeof allowance;
  appStore: typeof appStore;
  babies: typeof babies;
  careExport: typeof careExport;
  chat: typeof chat;
  chatAgent: typeof chatAgent;
  events: typeof events;
  "guidance/corpus": typeof guidance_corpus;
  http: typeof http;
  "lib/access": typeof lib_access;
  "lib/allowance": typeof lib_allowance;
  "lib/allowanceDb": typeof lib_allowanceDb;
  "lib/appleRootCa": typeof lib_appleRootCa;
  "lib/appStore": typeof lib_appStore;
  "lib/auth": typeof lib_auth;
  "lib/babyContext": typeof lib_babyContext;
  "lib/clothingAdvice": typeof lib_clothingAdvice;
  "lib/functions": typeof lib_functions;
  "lib/logEvents": typeof lib_logEvents;
  "lib/sharing": typeof lib_sharing;
  "lib/validators": typeof lib_validators;
  subscriptions: typeof subscriptions;
  users: typeof users;
  voiceLog: typeof voiceLog;
  voiceTools: typeof voiceTools;
}>;

/**
 * A utility for referencing Convex functions in your app's public API.
 *
 * Usage:
 * ```js
 * const myFunctionReference = api.myModule.myFunction;
 * ```
 */
export declare const api: FilterApi<
  typeof fullApi,
  FunctionReference<any, "public">
>;

/**
 * A utility for referencing Convex functions in your app's internal API.
 *
 * Usage:
 * ```js
 * const myFunctionReference = internal.myModule.myFunction;
 * ```
 */
export declare const internal: FilterApi<
  typeof fullApi,
  FunctionReference<any, "internal">
>;

export declare const components: {};
