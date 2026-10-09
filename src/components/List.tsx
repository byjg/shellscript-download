// ------------------------------------------------------------------------------------
// Auto-generated — List component built from public/scripts headers. Do not edit.
// ------------------------------------------------------------------------------------

import { useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { ArrowRight, Search } from "lucide-react";

const data = [{"base":"ant","description":"Download and install Apache Ant"},{"base":"aws-cli","description":"Download and install the AWS CLI v2"},{"base":"buildah","description":"Install Buildah on Linux, to build container images without a daemon"},{"base":"byjg-gluo","description":"Create a new Gluo project (composer create-project byjg/gluo) in unattended mode"},{"base":"byjg-repo","description":"Add the ByJG package repository (APT or RPM) to install ByJG tools"},{"base":"docker","description":"Install the Docker Engine on Linux in a safe, idempotent, shell-friendly way"},{"base":"doctl","description":"Download and install doctl, the DigitalOcean command-line tool"},{"base":"eksctl","description":"Download and install eksctl, the command-line tool for Amazon EKS clusters"},{"base":"gcloud","description":"Download and install the Google Cloud CLI (gcloud, gsutil, bq)"},{"base":"helm","description":"Download and install Helm, the Kubernetes package manager"},{"base":"java-corretto","description":"Download and install Amazon Corretto OpenJDK"},{"base":"java-oracle","description":"Download and install Oracle JDK"},{"base":"java-temurin","description":"Download and install Eclipse Temurin Java (OpenJDK)"},{"base":"jq","description":"Download and install jq, the command-line JSON processor"},{"base":"kubectl","description":"Download and install kubectl, the Kubernetes command-line tool"},{"base":"kustomize","description":"Download and install Kustomize, to customize Kubernetes manifests"},{"base":"load","description":"Fetch a script from https://shellscript.download, cache it locally, and optionally execute it."},{"base":"maven","description":"Download and install Apache Maven"},{"base":"node-docker","description":"Create Docker-backed Node.js launchers (node, npm, npx, yarn)"},{"base":"nvm","description":"Install Node Version Manager (NVM) and set up a shell init snippet"},{"base":"php-docker","description":"Create Docker-backed php and composer launchers"},{"base":"podman","description":"Install Podman on Linux, optionally answering to the 'docker' command"},{"base":"qemu","description":"Download QEMU and manage local virtual machines (start, list, stop, remove)"},{"base":"remove","description":"Remove installed tools from shellscript.download"},{"base":"ssh-agent","description":"Configure ssh-agent startup and SSH key loading in your shell"},{"base":"yq","description":"Download and install yq, the command-line YAML processor"}] as { base: string; description: string }[];

export default function List() {
  const [q, setQ] = useState("");
  const filtered = useMemo(() => {
    const query = q.toLowerCase().trim();
    if (!query) return data;
    return data.filter((item) => {
      return (
        item.base.toLowerCase().includes(query) ||
        item.description.toLowerCase().includes(query)
      );
    });
  }, [q]);

  return (
    <section id="packages" aria-labelledby="packages-title" className="scroll-mt-6">
      <h2 id="packages-title" className="mb-2 text-2xl font-bold">Find a package</h2>
      <p className="mb-4 text-sm text-muted-foreground">Browse all packages or search by name or description. Select one for installation instructions.</p>
      <label htmlFor="package-search" className="sr-only">Search packages</label>
      <div className="relative">
        <Search aria-hidden="true" className="pointer-events-none absolute left-4 top-4 h-5 w-5 text-muted-foreground" />
        <input
          id="package-search"
          type="search"
          placeholder="Search packages: docker, java, kubernetes…"
          value={q}
          onChange={(e) => setQ(e.target.value)}
          className="h-13 w-full rounded-lg border border-border bg-card pl-12 pr-4 text-base text-foreground focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent"
          aria-controls="package-results"
        />
      </div>
      <div className="my-4 flex flex-wrap items-center justify-between gap-2 text-sm">
        <p role="status" className="text-muted-foreground">
          {q.trim() ? filtered.length + " of " + data.length + " packages" : data.length + " packages · A–Z"}
        </p>
        {q && <button type="button" onClick={() => setQ("")} className="rounded text-accent underline underline-offset-4 focus-visible:outline-2 focus-visible:outline-accent">Clear search / Show all</button>}
      </div>
      <ul id="package-results" className="divide-y divide-border border-y border-border">
        {filtered.map(({ base, description }) => (
          <li key={base}>
            <Link to={"/scripts/" + base} className="group flex items-center gap-4 rounded px-3 py-4 transition-colors hover:bg-card focus-visible:outline-2 focus-visible:outline-accent">
              <div className="grid min-w-0 flex-1 gap-1 sm:grid-cols-[10rem_1fr] sm:gap-6">
                <span className="font-mono font-medium text-accent">{base}</span>
                <span className="text-sm text-muted-foreground group-hover:text-foreground">{description}</span>
              </div>
              <ArrowRight aria-hidden="true" className="h-4 w-4 shrink-0 text-muted-foreground group-hover:text-accent" />
            </Link>
          </li>
        ))}
      </ul>
      {filtered.length === 0 && (
        <p className="py-8 text-center text-muted-foreground">No packages found. Try another name or clear the search to see all packages.</p>
      )}
    </section>
  );
}
