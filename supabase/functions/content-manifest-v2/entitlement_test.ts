import { assertEquals } from "jsr:@std/assert@1";
import { isActivePremiumTransaction, isMatchingCurrentTransaction } from "./entitlement.ts";

Deno.test("premium payload accepts the configured non-consumable", () => {
  assertEquals(
    isActivePremiumTransaction({
      bundleId: "com.naoyaochiai.minukuru",
      productId: "com.naoyaochiai.minukuru.premium",
      transactionId: "2000000123456789",
      environment: "Sandbox",
    }),
    true,
  );
});

Deno.test("premium payload rejects a different product", () => {
  assertEquals(
    isActivePremiumTransaction({
      bundleId: "com.naoyaochiai.minukuru",
      productId: "example.other.product",
      transactionId: "2000000123456789",
    }),
    false,
  );
});

Deno.test("premium payload rejects a revoked transaction", () => {
  assertEquals(
    isActivePremiumTransaction({
      bundleId: "com.naoyaochiai.minukuru",
      productId: "com.naoyaochiai.minukuru.premium",
      transactionId: "2000000123456789",
      revocationDate: 1_800_000_000_000,
    }),
    false,
  );
});

Deno.test("current transaction must match the submitted transaction", () => {
  const submitted = {
    bundleId: "com.naoyaochiai.minukuru",
    productId: "com.naoyaochiai.minukuru.premium",
    transactionId: "2000000123456789",
    originalTransactionId: "2000000123456789",
  };

  assertEquals(isMatchingCurrentTransaction(submitted, submitted), true);
  assertEquals(
    isMatchingCurrentTransaction(submitted, { ...submitted, transactionId: "2000000999999999" }),
    false,
  );
  assertEquals(
    isMatchingCurrentTransaction(submitted, { ...submitted, revocationDate: 1_800_000_000_000 }),
    false,
  );
});
