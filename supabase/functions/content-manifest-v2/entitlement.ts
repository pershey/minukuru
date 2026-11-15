import { Buffer } from "node:buffer";
import {
  AppStoreServerAPIClient,
  Environment,
  SignedDataVerifier,
  type JWSTransactionDecodedPayload,
} from "npm:@apple/app-store-server-library@3.1.0";

const bundleID = "com.naoyaochiai.minukuru";
const premiumProductID = "com.naoyaochiai.minukuru.premium";

type EnvironmentReader = (key: string) => string | undefined;

export class EntitlementConfigurationError extends Error {}
export class EntitlementVerificationError extends Error {}
export class EntitlementServiceError extends Error {}

export function isActivePremiumTransaction(payload: JWSTransactionDecodedPayload): boolean {
  return payload.bundleId === bundleID &&
    payload.productId === premiumProductID &&
    typeof payload.transactionId === "string" &&
    payload.transactionId.length > 0 &&
    payload.revocationDate === undefined;
}

export function isMatchingCurrentTransaction(
  submitted: JWSTransactionDecodedPayload,
  current: JWSTransactionDecodedPayload,
): boolean {
  return isActivePremiumTransaction(current) &&
    current.transactionId === submitted.transactionId &&
    current.originalTransactionId === submitted.originalTransactionId;
}

export async function verifyPremiumTransaction(
  transactionJWS: string,
  readEnvironment: EnvironmentReader = (key) => Deno.env.get(key),
): Promise<JWSTransactionDecodedPayload> {
  if (!transactionJWS || transactionJWS.length > 20_000) {
    throw new EntitlementVerificationError("A valid StoreKit transaction is required.");
  }

  const rootCertificates = readRootCertificates(readEnvironment);
  const onlineChecks = readEnvironment("APPLE_ENABLE_ONLINE_CHECKS") === "true";
  const appAppleID = parseAppAppleID(readEnvironment("APPLE_APP_ID"));
  const verifiers = [
    new SignedDataVerifier(rootCertificates, onlineChecks, Environment.SANDBOX, bundleID),
  ];

  if (appAppleID !== undefined) {
    verifiers.push(
      new SignedDataVerifier(rootCertificates, onlineChecks, Environment.PRODUCTION, bundleID, appAppleID),
    );
  }

  let lastError: unknown;
  for (const verifier of verifiers) {
    try {
      const submitted = await verifier.verifyAndDecodeTransaction(transactionJWS);
      if (!isActivePremiumTransaction(submitted)) {
        throw new EntitlementVerificationError("The transaction does not grant premium access.");
      }

      const environment = submitted.environment === Environment.PRODUCTION
        ? Environment.PRODUCTION
        : submitted.environment === Environment.SANDBOX
        ? Environment.SANDBOX
        : undefined;
      if (!environment) {
        throw new EntitlementVerificationError("Unsupported StoreKit transaction environment.");
      }

      const current = await loadCurrentTransaction(
        submitted.transactionId!,
        environment,
        rootCertificates,
        onlineChecks,
        appAppleID,
        readEnvironment,
      );
      if (!isMatchingCurrentTransaction(submitted, current)) {
        throw new EntitlementVerificationError("The transaction is no longer active.");
      }
      return current;
    } catch (error) {
      if (error instanceof EntitlementConfigurationError || error instanceof EntitlementServiceError) {
        throw error;
      }
      lastError = error;
    }
  }

  if (appAppleID === undefined) {
    throw new EntitlementConfigurationError(
      "APPLE_APP_ID is required before production transactions can be verified.",
    );
  }

  throw new EntitlementVerificationError("The StoreKit transaction could not be verified.", {
    cause: lastError,
  });
}

async function loadCurrentTransaction(
  transactionID: string,
  environment: Environment,
  rootCertificates: Buffer[],
  onlineChecks: boolean,
  appAppleID: number | undefined,
  readEnvironment: EnvironmentReader,
): Promise<JWSTransactionDecodedPayload> {
  const issuerID = requireEnvironment(readEnvironment, "APPLE_IAP_ISSUER_ID");
  const keyID = requireEnvironment(readEnvironment, "APPLE_IAP_KEY_ID");
  const privateKeyBase64 = requireEnvironment(readEnvironment, "APPLE_IAP_PRIVATE_KEY_BASE64");
  const privateKey = Buffer.from(privateKeyBase64, "base64").toString("utf8");
  if (!privateKey.includes("BEGIN PRIVATE KEY")) {
    throw new EntitlementConfigurationError("APPLE_IAP_PRIVATE_KEY_BASE64 is invalid.");
  }

  try {
    const client = new AppStoreServerAPIClient(privateKey, keyID, issuerID, bundleID, environment);
    const response = await client.getTransactionInfo(transactionID);
    if (!response.signedTransactionInfo) {
      throw new EntitlementServiceError("Apple returned no signed transaction information.");
    }
    const verifier = new SignedDataVerifier(
      rootCertificates,
      onlineChecks,
      environment,
      bundleID,
      environment === Environment.PRODUCTION ? appAppleID : undefined,
    );
    return await verifier.verifyAndDecodeTransaction(response.signedTransactionInfo);
  } catch (error) {
    if (error instanceof EntitlementConfigurationError || error instanceof EntitlementServiceError) {
      throw error;
    }
    throw new EntitlementServiceError("Apple transaction status could not be checked.", { cause: error });
  }
}

function readRootCertificates(readEnvironment: EnvironmentReader): Buffer[] {
  const rawValue = readEnvironment("APPLE_ROOT_CERTIFICATES_BASE64_JSON");
  if (!rawValue) {
    throw new EntitlementConfigurationError("Apple root certificates are not configured.");
  }

  try {
    const values = JSON.parse(rawValue);
    if (!Array.isArray(values) || values.length === 0 || values.some((value) => typeof value !== "string")) {
      throw new Error("Expected a non-empty string array.");
    }
    return values.map((value) => Buffer.from(value, "base64"));
  } catch (error) {
    throw new EntitlementConfigurationError("Apple root certificates are invalid.", { cause: error });
  }
}

function parseAppAppleID(rawValue: string | undefined): number | undefined {
  if (!rawValue) {
    return undefined;
  }
  const value = Number(rawValue);
  if (!Number.isSafeInteger(value) || value <= 0) {
    throw new EntitlementConfigurationError("APPLE_APP_ID must be a positive integer.");
  }
  return value;
}

function requireEnvironment(readEnvironment: EnvironmentReader, key: string): string {
  const value = readEnvironment(key)?.trim();
  if (!value) {
    throw new EntitlementConfigurationError(`${key} is required.`);
  }
  return value;
}
