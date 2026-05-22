// api/src/otel.ts
//
// Spec G B: env-gated OTel SDK. No-op without OTEL_EXPORTER_OTLP_ENDPOINT
// so dev + tests stay fast. Initialise BEFORE Sentry / Nest.
import { NodeSDK } from '@opentelemetry/sdk-node';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';

let sdk: NodeSDK | null = null;

export function initOtel(): void {
  const endpoint = process.env.OTEL_EXPORTER_OTLP_ENDPOINT;
  if (!endpoint) return; // no-op in dev / tests

  sdk = new NodeSDK({
    serviceName: process.env.OTEL_SERVICE_NAME || 'dukon-api',
    traceExporter: new OTLPTraceExporter({ url: `${endpoint}/v1/traces` }),
    instrumentations: [
      getNodeAutoInstrumentations({
        '@opentelemetry/instrumentation-fs': { enabled: false },
      }),
    ],
  });
  sdk.start();
}

export async function shutdownOtel(): Promise<void> {
  if (sdk) await sdk.shutdown();
}
