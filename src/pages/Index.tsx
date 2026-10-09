import { useState } from "react";
import { ArrowDown, ChevronDown, Terminal } from "lucide-react";
import { CompatibilityModal } from "@/components/CompatibilityModal";
import { InstallCommand } from "@/components/InstallCommand";
import List from "@/components/List.tsx";

const Index = () => {
  const [showSetup, setShowSetup] = useState(false);

  return (
  <main className="min-h-screen bg-(--gradient-hero)">
    <div className="mx-auto max-w-5xl px-4 py-8 sm:px-6 sm:py-12">
      <header className="mb-10 pt-4 sm:pt-8">
        <h1 className="mb-5 flex items-center gap-2 text-[clamp(1.5rem,5.7vw,4.5rem)] font-bold tracking-tight sm:gap-4">
          <Terminal className="h-[0.8em] w-[0.8em] shrink-0 text-accent" aria-hidden="true" />
          <span>Shellscript<span className="text-accent">.Download</span></span>
        </h1>
        <p className="mb-2 text-xl font-medium sm:text-2xl">
          Your favorite Linux tools. One command away.
        </p>
        <p className="max-w-2xl text-base text-muted-foreground sm:text-lg">
          Set up once, then choose from the packages below.
        </p>
        <div className="mt-7 flex flex-wrap items-center gap-3">
          <button
            type="button"
            aria-expanded={showSetup}
            aria-controls="getting-started"
            onClick={() => setShowSetup(!showSetup)}
            className="inline-flex min-h-12 items-center justify-center gap-3 rounded-lg bg-accent px-5 py-3 text-left font-semibold text-accent-foreground hover:bg-accent/90 focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-accent"
          >
            First time? Install Shellscript.Download
            <ChevronDown aria-hidden="true" className={"h-5 w-5 shrink-0 transition-transform " + (showSetup ? "rotate-180" : "")} />
          </button>
          <a href="#packages" className="inline-flex min-h-12 items-center gap-2 rounded-lg border border-border px-5 py-3 font-medium hover:bg-card focus-visible:outline-2 focus-visible:outline-accent">
            Browse packages <ArrowDown aria-hidden="true" className="h-4 w-4" />
          </a>
        </div>
      </header>
      <section hidden={!showSetup} id="getting-started" aria-labelledby="setup-title" className="mb-10 rounded-xl border border-accent/40 bg-card/60 p-5 sm:p-8">
        <h2 id="setup-title" className="mb-2 text-2xl font-semibold">Get ready to install packages</h2>
        <p className="mb-7 text-muted-foreground">
          This setup adds <code className="font-mono text-foreground">load.sh</code> to your terminal — the command you’ll use to install packages. You only need to do this once.
        </p>
        <ol className="space-y-7">
          <li className="flex gap-3 sm:gap-4">
            <span aria-hidden="true" className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-accent/15 font-semibold text-accent">1</span>
            <div className="min-w-0 flex-1">
              <h3 className="mb-2 text-lg font-semibold">Copy this command into your terminal</h3>
              <p className="mb-3 text-sm text-muted-foreground">Open the Terminal app on your Linux computer. Click Copy below, paste into the terminal, and press Enter. Wait for the installation to finish.</p>
              <InstallCommand command={'/bin/bash -c "$(curl -fsSL https://shellscript.download/install/loader)"'} />
              <details className="mt-3 text-sm text-muted-foreground">
                <summary className="cursor-pointer rounded text-accent focus-visible:outline-2 focus-visible:outline-accent">Seeing “curl: command not found”?</summary>
                <p className="my-3">Use this alternative command if you have wget installed:</p>
                <InstallCommand command={'/bin/bash -c "$(wget -qO- https://shellscript.download/install/loader)"'} />
              </details>
            </div>
          </li>
          <li className="flex gap-3 sm:gap-4">
            <span aria-hidden="true" className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-accent/15 font-semibold text-accent">2</span>
            <div>
              <h3 className="mb-2 text-lg font-semibold">Close your terminal and open it again</h3>
              <p className="text-sm text-muted-foreground">The new terminal will recognize the <code className="font-mono text-foreground">load.sh</code> command.</p>
            </div>
          </li>
          <li className="flex gap-3 sm:gap-4">
            <span aria-hidden="true" className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-accent/15 font-semibold text-accent">3</span>
            <div>
              <h3 className="mb-2 text-lg font-semibold">Choose your first package</h3>
              <p className="mb-4 text-sm text-muted-foreground">Find a package below and open its page. Copy its installation command and run it in your new terminal.</p>
              <a href="#packages" className="inline-flex items-center gap-2 rounded-lg bg-accent px-4 py-2 font-semibold text-accent-foreground hover:bg-accent/90 focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-accent">Find a package <ArrowDown aria-hidden="true" className="h-4 w-4" /></a>
            </div>
          </li>
        </ol>
        <div className="mt-6 border-t border-border pt-4">
          <CompatibilityModal />
        </div>
      </section>
      <List />
    </div>
  </main>
  );
};

export default Index;
