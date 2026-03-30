import {
  AlertTriangle,
  ArrowRight,
  BadgeCheck,
  Database,
  Layers3,
  RefreshCcw,
  Smartphone,
  Store,
} from "lucide-react";

import { iapAuditSnapshot, type Tone } from "./lib/iapAuditSnapshot";

function toneClasses(tone: Tone) {
  switch (tone) {
    case "healthy":
      return "border-emerald-500/20 bg-emerald-500/10 text-emerald-900";
    case "warning":
      return "border-amber-500/20 bg-amber-500/10 text-amber-950";
    case "risk":
      return "border-rose-500/20 bg-rose-500/10 text-rose-950";
    case "info":
      return "border-sky-500/20 bg-sky-500/10 text-sky-950";
  }
}

function toneDot(tone: Tone) {
  switch (tone) {
    case "healthy":
      return "bg-emerald-500";
    case "warning":
      return "bg-amber-500";
    case "risk":
      return "bg-rose-500";
    case "info":
      return "bg-sky-500";
  }
}

function Section({
  id,
  eyebrow,
  title,
  body,
  children,
}: {
  id: string;
  eyebrow: string;
  title: string;
  body: string;
  children: React.ReactNode;
}) {
  return (
    <section id={id} className="pw-card rounded-[26px] border border-[var(--pw-line)] bg-white/75 p-5 shadow-[var(--pw-shadow)] backdrop-blur md:p-7">
      <div className="mb-5 flex flex-col gap-2 md:mb-6">
        <div className="pw-mono text-[11px] uppercase tracking-[0.24em] text-[var(--pw-muted)]">
          {eyebrow}
        </div>
        <div className="flex flex-col gap-2 md:flex-row md:items-end md:justify-between">
          <div className="max-w-3xl">
            <h2 className="pw-display text-2xl tracking-tight text-[var(--pw-ink)]">{title}</h2>
            <p className="mt-2 text-sm leading-6 text-[var(--pw-muted)]">{body}</p>
          </div>
        </div>
      </div>
      {children}
    </section>
  );
}

function SmallPill({ tone, children }: { tone: Tone; children: React.ReactNode }) {
  return (
    <span
      className={`inline-flex items-center gap-2 rounded-full border px-3 py-1 text-[11px] font-semibold uppercase tracking-[0.18em] ${toneClasses(
        tone
      )}`}
    >
      <span className={`size-2 rounded-full ${toneDot(tone)}`}></span>
      {children}
    </span>
  );
}

function KeyValueList({
  items,
}: {
  items: ReadonlyArray<{
    label: string;
    value: string;
    tone?: Tone;
    note?: string;
  }>;
}) {
  return (
    <div className="grid gap-3">
      {items.map((item) => (
        <div key={item.label} className="pw-subcard">
          <div className="mb-2 flex flex-wrap items-center justify-between gap-3">
            <div className="pw-mono text-[11px] uppercase tracking-[0.18em] text-[var(--pw-muted)]">
              {item.label}
            </div>
            {item.tone ? <SmallPill tone={item.tone}>{item.tone}</SmallPill> : null}
          </div>
          <div className="text-sm font-semibold text-[var(--pw-ink)]">{item.value}</div>
          {item.note ? <div className="mt-1 text-xs leading-5 text-[var(--pw-muted)]">{item.note}</div> : null}
        </div>
      ))}
    </div>
  );
}

function DriftList({
  items,
}: {
  items: ReadonlyArray<{
    title: string;
    tone: Tone;
    body: string;
  }>;
}) {
  return (
    <div className="grid gap-3">
      {items.map((item) => (
        <div key={item.title} className={`rounded-[20px] border p-4 ${toneClasses(item.tone)}`}>
          <div className="mb-2 flex items-center gap-2 text-sm font-semibold">
            {item.tone === "healthy" ? (
              <BadgeCheck className="size-4" />
            ) : item.tone === "warning" ? (
              <RefreshCcw className="size-4" />
            ) : (
              <AlertTriangle className="size-4" />
            )}
            {item.title}
          </div>
          <p className="text-sm leading-6">{item.body}</p>
        </div>
      ))}
    </div>
  );
}

export default function IapStatusPage() {
  return (
    <main className="mx-auto flex w-full max-w-[1380px] flex-col gap-6 px-4 py-8 md:px-6 md:py-10">
      <header className="pw-card overflow-hidden rounded-[32px] border border-[var(--pw-line)] bg-[linear-gradient(140deg,color-mix(in_oklch,white_84%,var(--pw-bg))_0%,color-mix(in_oklch,var(--pw-accent)_12%,white)_45%,color-mix(in_oklch,var(--pw-accent-2)_10%,white)_100%)] p-6 shadow-[var(--pw-shadow)] md:p-8">
        <div className="grid gap-8 lg:grid-cols-[1.15fr_0.85fr]">
          <div>
            <div className="mb-3 flex flex-wrap items-center gap-2">
              <SmallPill tone="info">temporary audit UI</SmallPill>
              <SmallPill tone="healthy">{iapAuditSnapshot.capturedAt}</SmallPill>
            </div>
            <h1 className="pw-display max-w-4xl text-4xl tracking-tight text-[var(--pw-ink)] md:text-5xl">
              Patchwork in-app purchase state across paywall, RevenueCat, App Store Connect, and Convex.
            </h1>
            <p className="mt-4 max-w-3xl text-base leading-7 text-[var(--pw-muted)]">
              This page is a point-in-time commerce audit captured on {iapAuditSnapshot.capturedAt}. It combines live
              RevenueCat and App Store Connect reads with the current local iOS and backend code paths, so you can see
              where the catalog is aligned and where release risk still exists.
            </p>
            <div className="mt-6 flex flex-wrap gap-3 text-sm">
              <a href="#paywall" className="inline-flex items-center gap-2 rounded-full border border-[var(--pw-line)] bg-white/70 px-4 py-2 text-[var(--pw-ink)] transition hover:bg-white">
                <Smartphone className="size-4" />
                Paywall
              </a>
              <a href="#catalog" className="inline-flex items-center gap-2 rounded-full border border-[var(--pw-line)] bg-white/70 px-4 py-2 text-[var(--pw-ink)] transition hover:bg-white">
                <Layers3 className="size-4" />
                Catalog matrix
              </a>
              <a href="#systems" className="inline-flex items-center gap-2 rounded-full border border-[var(--pw-line)] bg-white/70 px-4 py-2 text-[var(--pw-ink)] transition hover:bg-white">
                <Store className="size-4" />
                Systems
              </a>
              <a href="#next-steps" className="inline-flex items-center gap-2 rounded-full border border-[var(--pw-line)] bg-white/70 px-4 py-2 text-[var(--pw-ink)] transition hover:bg-white">
                <ArrowRight className="size-4" />
                Next steps
              </a>
            </div>
          </div>

          <div className="grid gap-3 sm:grid-cols-2">
            {iapAuditSnapshot.summaryTiles.map((tile, index) => (
              <div key={tile.label} className={`pw-fade-up rounded-[24px] border border-[var(--pw-line)] bg-white/75 p-5 backdrop-blur ${index === 0 ? "sm:col-span-2" : ""}`}>
                <div className="mb-2 flex items-center justify-between gap-3">
                  <div className="pw-mono text-[11px] uppercase tracking-[0.18em] text-[var(--pw-muted)]">
                    {tile.label}
                  </div>
                  <SmallPill tone={tile.tone}>{tile.tone}</SmallPill>
                </div>
                <div className="pw-display text-3xl tracking-tight text-[var(--pw-ink)]">{tile.value}</div>
                <p className="mt-2 text-sm leading-6 text-[var(--pw-muted)]">{tile.note}</p>
              </div>
            ))}
          </div>
        </div>
      </header>

      <Section
        id="overview"
        eyebrow="Readout"
        title="What matters right now"
        body="These are the high-signal findings from the current audit snapshot, not generic subscription advice."
      >
        <div className="grid gap-3 md:grid-cols-2">
          {iapAuditSnapshot.executiveSummary.map((item, index) => (
            <div key={item} className="pw-subcard">
              <div className="mb-3 flex items-center gap-3">
                <div className="pw-display flex size-8 items-center justify-center rounded-full bg-[color-mix(in_oklch,var(--pw-accent)_14%,white)] text-sm text-[var(--pw-ink)]">
                  {index + 1}
                </div>
                <div className="pw-mono text-[11px] uppercase tracking-[0.18em] text-[var(--pw-muted)]">
                  Finding {index + 1}
                </div>
              </div>
              <p className="text-sm leading-6 text-[var(--pw-ink)]">{item}</p>
            </div>
          ))}
        </div>
      </Section>

      <Section
        id="paywall"
        eyebrow="Paywall"
        title="How the current paywall looks"
        body="This is the real native iOS billing sheet structure as implemented today. The UI is custom SwiftUI, the product plumbing is RevenueCat-backed, and the remaining drift is store-side naming rather than pricing."
      >
        <div className="grid gap-6 xl:grid-cols-[0.9fr_1.1fr]">
          <div className="rounded-[28px] border border-[var(--pw-line)] bg-[linear-gradient(180deg,#eef5ff_0%,#f8fbff_34%,#ffffff_100%)] p-4">
            <div className="mx-auto max-w-[360px] rounded-[34px] border border-slate-900/10 bg-white px-4 pb-5 pt-4 shadow-[0_30px_90px_rgba(20,40,80,0.12)]">
              <div className="mx-auto mb-4 h-1.5 w-20 rounded-full bg-slate-900/10"></div>
              <div className="mb-4">
                <div className="flex items-start justify-between gap-3">
                  <div className="max-w-[250px]">
                    <div className="pw-display mt-1 text-3xl tracking-tight text-[var(--pw-ink)]">
                      {iapAuditSnapshot.paywall.headline}
                    </div>
                    <p className="mt-2 text-sm leading-6 text-[var(--pw-muted)]">{iapAuditSnapshot.paywall.body}</p>
                  </div>
                  <div className="flex size-9 items-center justify-center rounded-full border border-[var(--pw-line)] bg-white/80 text-[var(--pw-muted)]">
                    ×
                  </div>
                </div>
              </div>

              <div className="mb-4 rounded-[24px] border border-[var(--pw-line)] bg-[linear-gradient(145deg,rgba(99,102,241,0.12),rgba(56,189,248,0.14),rgba(255,255,255,0.92))] px-4 py-5 shadow-[0_12px_30px_rgba(37,99,235,0.08)]">
                <div className="mb-3 flex items-center justify-between">
                  <div className="pw-mono text-[11px] uppercase tracking-[0.18em] text-[var(--pw-muted)]">
                    spotlight art
                  </div>
                  <SmallPill tone="info">hero</SmallPill>
                </div>
                <div className="grid grid-cols-[1.05fr_0.95fr] gap-3">
                  <div className="rounded-[18px] bg-white/85 p-3 shadow-[0_10px_24px_rgba(15,23,42,0.08)]">
                    <div className="mb-2 h-3 w-20 rounded-full bg-[color-mix(in_oklch,var(--pw-accent)_24%,white)]"></div>
                    <div className="mb-3 flex items-center gap-3">
                      <div className="size-10 rounded-2xl bg-[linear-gradient(140deg,rgba(99,102,241,0.85),rgba(59,130,246,0.72))]"></div>
                      <div className="grid gap-1">
                        <div className="h-2.5 w-20 rounded-full bg-slate-900/70"></div>
                        <div className="h-2 w-16 rounded-full bg-slate-900/20"></div>
                      </div>
                    </div>
                    <div className="space-y-2">
                      <div className="h-2 w-full rounded-full bg-slate-900/10"></div>
                      <div className="h-2 w-4/5 rounded-full bg-slate-900/10"></div>
                    </div>
                  </div>
                  <div className="relative rounded-[20px] bg-[radial-gradient(circle_at_center,rgba(99,102,241,0.22)_0,rgba(99,102,241,0.08)_30%,transparent_31%),radial-gradient(circle_at_center,rgba(59,130,246,0.18)_0,rgba(59,130,246,0.06)_52%,transparent_53%)]">
                    <div className="absolute left-1/2 top-1/2 size-16 -translate-x-1/2 -translate-y-1/2 rounded-full border-2 border-[var(--pw-accent)]/60"></div>
                    <div className="absolute left-1/2 top-1/2 size-7 -translate-x-1/2 -translate-y-1/2 rounded-full bg-[var(--pw-accent)]/20 ring-2 ring-[var(--pw-accent)]/30"></div>
                    <div className="absolute left-7 top-8 h-0.5 w-24 -rotate-[26deg] bg-[linear-gradient(90deg,rgba(99,102,241,0.0),rgba(99,102,241,0.85),rgba(56,189,248,0.85))]"></div>
                  </div>
                </div>
              </div>

              <div className="space-y-3">
                {iapAuditSnapshot.paywall.packages.map((pkg, index) => (
                  <div
                    key={pkg.title}
                    className={`rounded-[22px] border p-4 shadow-[0_12px_28px_rgba(15,23,42,0.05)] ${
                      index === 1
                        ? "border-[color:var(--pw-accent)] bg-[linear-gradient(180deg,rgba(255,255,255,0.98),rgba(238,245,255,0.96))] ring-2 ring-[color:var(--pw-accent)]/15"
                        : "border-[var(--pw-line)] bg-[color-mix(in_oklch,white_88%,var(--pw-bg))]"
                    }`}
                  >
                    <div className="flex items-start justify-between gap-3">
                      <div>
                        {index === 1 ? (
                          <div className="mb-2 inline-flex rounded-full border border-[color:var(--pw-accent)]/15 bg-[color:var(--pw-accent)]/10 px-2.5 py-1 text-[10px] font-semibold uppercase tracking-[0.18em] text-[color:var(--pw-accent)]">
                            Best Value
                          </div>
                        ) : null}
                        <div className="text-sm font-semibold text-[var(--pw-ink)]">{pkg.title}</div>
                        <div className="mt-1 text-sm leading-6 text-[var(--pw-muted)]">{pkg.subtitle}</div>
                        <div className="mt-2 pw-mono text-[11px] uppercase tracking-[0.18em] text-[var(--pw-muted)]">
                          {pkg.buttonLabel}
                        </div>
                      </div>
                      <div
                        className={`mt-1 size-5 rounded-full border ${
                          index === 1
                            ? "border-[color:var(--pw-accent)] bg-[color:var(--pw-accent)]/15"
                            : "border-[var(--pw-line)] bg-white"
                        }`}
                      ></div>
                    </div>
                    <div className="mt-3 text-xs leading-5 text-[var(--pw-muted)]">{pkg.priceNote}</div>
                  </div>
                ))}
              </div>

              <div className="mt-4 rounded-[18px] bg-[linear-gradient(90deg,var(--pw-accent),var(--pw-accent-2))] px-4 py-3 text-center text-sm font-semibold text-white shadow-[0_10px_24px_rgba(37,99,235,0.18)]">
                Join Founders Club
              </div>

              <div className="mt-4 rounded-[18px] border border-dashed border-[var(--pw-line)] px-4 py-3 text-center text-sm text-[var(--pw-muted)]">
                Restore purchases
              </div>
            </div>
          </div>

          <div className="grid gap-4">
            <div className="grid gap-3 md:grid-cols-2">
              <div className="pw-subcard">
                <div className="mb-2 flex items-center gap-2">
                  <Smartphone className="size-4 text-[var(--pw-accent)]" />
                  <div className="text-sm font-semibold text-[var(--pw-ink)]">Screen source</div>
                </div>
                <p className="text-sm leading-6 text-[var(--pw-muted)]">{iapAuditSnapshot.paywall.source}</p>
              </div>
              <div className="pw-subcard">
                <div className="mb-2 flex items-center gap-2">
                  <Store className="size-4 text-[var(--pw-accent)]" />
                  <div className="text-sm font-semibold text-[var(--pw-ink)]">RevenueCat lookup</div>
                </div>
                <p className="text-sm leading-6 text-[var(--pw-muted)]">
                  Offering <code className="pw-mono text-[12px]">tasker_access_paywall</code>, entitlement{" "}
                  <code className="pw-mono text-[12px]">tasker_access</code>, products{" "}
                  <code className="pw-mono text-[12px]">subscription</code> and{" "}
                  <code className="pw-mono text-[12px]">lifetime</code>.
                </p>
              </div>
            </div>

            <div className="pw-subcard">
              <div className="mb-3 text-sm font-semibold text-[var(--pw-ink)]">Behavioral notes</div>
              <div className="grid gap-3">
                {iapAuditSnapshot.paywall.behavior.map((item) => (
                  <div key={item} className="flex gap-3 text-sm leading-6 text-[var(--pw-muted)]">
                    <span className="mt-2 size-1.5 flex-none rounded-full bg-[var(--pw-accent)]"></span>
                    <span>{item}</span>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      </Section>

      <Section
        id="catalog"
        eyebrow="Catalog"
        title="Subscription and lifetime product matrix"
        body="Each row below maps the normalized tasker payment modes through the native paywall, RevenueCat, App Store Connect, and backend contract."
      >
        <div className="grid gap-4 xl:grid-cols-2">
          {iapAuditSnapshot.catalogRows.map((row) => (
            <article key={row.id} className="overflow-hidden rounded-[24px] border border-[var(--pw-line)] bg-white">
              <div className="border-b border-[var(--pw-line)] bg-[color-mix(in_oklch,white_84%,var(--pw-bg))] px-5 py-4">
                <div className="flex items-start justify-between gap-3">
                  <div>
                    <div className="pw-mono text-[11px] uppercase tracking-[0.18em] text-[var(--pw-muted)]">
                      {row.id}
                    </div>
                    <h3 className="mt-1 text-xl font-semibold tracking-tight text-[var(--pw-ink)]">{row.title}</h3>
                    <p className="mt-1 text-sm leading-6 text-[var(--pw-muted)]">{row.subtitle}</p>
                  </div>
                  <SmallPill tone={row.statusTone}>
                    {row.statusLabel}
                  </SmallPill>
                </div>
              </div>
              <div className="grid gap-px bg-[var(--pw-line)] md:grid-cols-2">
                <div className="bg-white p-5">
                  <div className="mb-3 flex items-center gap-2 text-sm font-semibold text-[var(--pw-ink)]">
                    <Smartphone className="size-4 text-[var(--pw-accent)]" />
                    Paywall
                  </div>
                  <div className="space-y-2 text-sm leading-6 text-[var(--pw-muted)]">
                    <p>
                      Native screen label is driven by the product mapping for{" "}
                      <code className="pw-mono text-[12px]">{row.productId}</code>.
                    </p>
                    <p>{row.nativePriceNote}</p>
                  </div>
                </div>

                <div className="bg-white p-5">
                  <div className="mb-3 flex items-center gap-2 text-sm font-semibold text-[var(--pw-ink)]">
                    <Store className="size-4 text-[var(--pw-accent)]" />
                    RevenueCat
                  </div>
                  <div className="space-y-2 text-sm leading-6 text-[var(--pw-muted)]">
                    <p>
                      Product <code className="pw-mono text-[12px]">{row.revenueCatProductId}</code> is{" "}
                      <strong className="text-[var(--pw-ink)]">{row.revenueCatState}</strong> and typed as{" "}
                      {row.revenueCatType}.
                    </p>
                    <p>
                      Package <code className="pw-mono text-[12px]">{row.revenueCatPackage}</code> lives in offering{" "}
                      <code className="pw-mono text-[12px]">{row.revenueCatOffering}</code>.
                    </p>
                    <p>
                      Entitlement bridge: <code className="pw-mono text-[12px]">{row.entitlement}</code>.
                    </p>
                  </div>
                </div>

                <div className="bg-white p-5">
                  <div className="mb-3 flex items-center gap-2 text-sm font-semibold text-[var(--pw-ink)]">
                    <Layers3 className="size-4 text-[var(--pw-accent)]" />
                    App Store Connect
                  </div>
                  <div className="space-y-2 text-sm leading-6 text-[var(--pw-muted)]">
                    <p>
                      Product <code className="pw-mono text-[12px]">{row.appStoreConnectId}</code> is currently{" "}
                      <strong className="text-[var(--pw-ink)]">{row.appStoreState}</strong>.
                    </p>
                    <p>{row.appStoreAvailability}</p>
                    <p>{row.appStorePricing}</p>
                    <p>{row.appStoreLocalization}</p>
                  </div>
                </div>

                <div className="bg-white p-5">
                  <div className="mb-3 flex items-center gap-2 text-sm font-semibold text-[var(--pw-ink)]">
                    <Database className="size-4 text-[var(--pw-accent)]" />
                    Backend
                  </div>
                  <div className="space-y-2 text-sm leading-6 text-[var(--pw-muted)]">
                    <p>{row.backendShape}</p>
                    <p>{row.backendBehavior}</p>
                  </div>
                </div>
              </div>
            </article>
          ))}
        </div>
      </Section>

      <Section
        id="systems"
        eyebrow="Systems"
        title="What each system has configured"
        body="This separates confirmed live configuration from contract assumptions and highlights where drift exists today."
      >
        <div className="grid gap-5 xl:grid-cols-3">
          <div className="grid gap-4">
            <div className="flex items-center gap-3">
              <Store className="size-5 text-[var(--pw-accent)]" />
              <h3 className="text-lg font-semibold tracking-tight text-[var(--pw-ink)]">RevenueCat</h3>
            </div>
            <KeyValueList items={iapAuditSnapshot.revenueCat.facts} />
            <div className="pw-subcard">
              <div className="mb-3 text-sm font-semibold text-[var(--pw-ink)]">Configured today</div>
              <div className="grid gap-3">
                {iapAuditSnapshot.revenueCat.products.map((item) => (
                  <div key={item} className="flex gap-3 text-sm leading-6 text-[var(--pw-muted)]">
                    <span className="mt-2 size-1.5 flex-none rounded-full bg-[var(--pw-accent)]"></span>
                    <span>{item}</span>
                  </div>
                ))}
              </div>
            </div>
            <DriftList items={iapAuditSnapshot.revenueCat.drifts} />
          </div>

          <div className="grid gap-4">
            <div className="flex items-center gap-3">
              <Layers3 className="size-5 text-[var(--pw-accent)]" />
              <h3 className="text-lg font-semibold tracking-tight text-[var(--pw-ink)]">App Store Connect</h3>
            </div>
            <KeyValueList items={iapAuditSnapshot.appStoreConnect.facts} />
            <div className="pw-subcard">
              <div className="mb-3 text-sm font-semibold text-[var(--pw-ink)]">Assets and metadata</div>
              <div className="grid gap-3">
                {iapAuditSnapshot.appStoreConnect.assets.map((item) => (
                  <div key={item} className="flex gap-3 text-sm leading-6 text-[var(--pw-muted)]">
                    <span className="mt-2 size-1.5 flex-none rounded-full bg-[var(--pw-accent-2)]"></span>
                    <span>{item}</span>
                  </div>
                ))}
              </div>
            </div>
            <DriftList items={iapAuditSnapshot.appStoreConnect.drifts} />
          </div>

          <div className="grid gap-4">
            <div className="flex items-center gap-3">
              <Database className="size-5 text-[var(--pw-accent)]" />
              <h3 className="text-lg font-semibold tracking-tight text-[var(--pw-ink)]">Backend and web contract</h3>
            </div>
            <KeyValueList items={iapAuditSnapshot.backend.facts} />
            <div className="pw-subcard">
              <div className="mb-3 text-sm font-semibold text-[var(--pw-ink)]">Configured realities</div>
              <div className="grid gap-3">
                {iapAuditSnapshot.backend.realities.map((item) => (
                  <div key={item} className="flex gap-3 text-sm leading-6 text-[var(--pw-muted)]">
                    <span className="mt-2 size-1.5 flex-none rounded-full bg-[var(--pw-accent)]"></span>
                    <span>{item}</span>
                  </div>
                ))}
              </div>
            </div>
            <DriftList items={iapAuditSnapshot.backend.drifts} />
          </div>
        </div>
      </Section>

      <Section
        id="next-steps"
        eyebrow="Action"
        title="Recommended next steps"
        body="Ordered by release risk and blast radius. These are the tasks that would most improve alignment across the four systems."
      >
        <div className="grid gap-4">
          {iapAuditSnapshot.nextSteps.map((step, index) => (
            <div key={step.title} className="pw-subcard">
              <div className="flex flex-col gap-4 md:flex-row md:items-start md:justify-between">
                <div className="flex gap-4">
                  <div className="pw-display flex size-10 flex-none items-center justify-center rounded-full bg-[color-mix(in_oklch,var(--pw-accent)_15%,white)] text-base text-[var(--pw-ink)]">
                    {index + 1}
                  </div>
                  <div>
                    <div className="mb-2 flex flex-wrap items-center gap-2">
                      <SmallPill tone={step.priority === "P0" ? "risk" : "warning"}>{step.priority}</SmallPill>
                      <span className="pw-mono text-[11px] uppercase tracking-[0.18em] text-[var(--pw-muted)]">
                        {step.owner}
                      </span>
                    </div>
                    <h3 className="text-lg font-semibold tracking-tight text-[var(--pw-ink)]">{step.title}</h3>
                    <p className="mt-2 max-w-4xl text-sm leading-6 text-[var(--pw-muted)]">{step.detail}</p>
                  </div>
                </div>
                <ArrowRight className="hidden size-5 flex-none text-[var(--pw-muted)] md:block" />
              </div>
            </div>
          ))}
        </div>
      </Section>

      <Section
        id="provenance"
        eyebrow="Provenance"
        title="Where this page got its facts"
        body="This view is intentionally transparent about which parts are direct reads and which parts come from local code."
      >
        <div className="grid gap-3">
          {iapAuditSnapshot.sourceNotes.map((item) => (
            <div key={item} className="pw-subcard text-sm leading-6 text-[var(--pw-muted)]">
              {item}
            </div>
          ))}
        </div>
      </Section>
    </main>
  );
}
