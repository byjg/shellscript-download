// ------------------------------------------------------------------------------------
// Auto-generated — List component built from public/scripts headers. Do not edit.
// ------------------------------------------------------------------------------------

import { useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { Terminal } from "lucide-react";

const data = [{"base":"ant","firstLine":"ant.sh: Download and install Apache Ant"},{"base":"aws-cli","firstLine":"aws-cli.sh: Download and install the AWS CLI v2"},{"base":"buildah","firstLine":"buildah.sh: Install Buildah on Linux, to build container images without a daemon"},{"base":"byjg-gluo","firstLine":"byjg-gluo.sh: Create a new Gluo project (composer create-project byjg/gluo) in unattended mode"},{"base":"docker","firstLine":"docker.sh: Install the Docker Engine on Linux in a safe, idempotent, shell-friendly way"},{"base":"doctl","firstLine":"doctl.sh: Download and install doctl, the DigitalOcean command-line tool"},{"base":"eksctl","firstLine":"eksctl.sh: Download and install eksctl, the command-line tool for Amazon EKS clusters"},{"base":"gcloud","firstLine":"gcloud.sh: Download and install the Google Cloud CLI (gcloud, gsutil, bq)"},{"base":"helm","firstLine":"helm.sh: Download and install Helm, the Kubernetes package manager"},{"base":"java-corretto","firstLine":"java-corretto.sh: Download and install Amazon Corretto OpenJDK"},{"base":"java-oracle","firstLine":"java-oracle.sh: Download and install Oracle JDK"},{"base":"java-temurin","firstLine":"java-temurin.sh: Download and install Eclipse Temurin Java (OpenJDK)"},{"base":"jq","firstLine":"jq.sh: Download and install jq, the command-line JSON processor"},{"base":"kubectl","firstLine":"kubectl.sh: Download and install kubectl, the Kubernetes command-line tool"},{"base":"kustomize","firstLine":"kustomize.sh: Download and install Kustomize, to customize Kubernetes manifests"},{"base":"load","firstLine":"load.sh: Fetch a script from https://shellscript.download, cache it locally,"},{"base":"maven","firstLine":"maven.sh: Download and install Apache Maven"},{"base":"node-docker","firstLine":"node-docker.sh: Create Docker-backed Node.js launchers (node, npm, npx, yarn)"},{"base":"nvm","firstLine":"nvm.sh: Install Node Version Manager (NVM) and set up a shell init snippet"},{"base":"php-docker","firstLine":"php-docker.sh: Create Docker-backed php and composer launchers"},{"base":"podman","firstLine":"podman.sh: Install Podman on Linux, optionally answering to the 'docker' command"},{"base":"qemu","firstLine":"qemu.sh: Download QEMU and manage local virtual machines (start, list, stop, remove)"},{"base":"remove","firstLine":"remove.sh: Remove installed tools from shellscript.download"},{"base":"ssh-agent","firstLine":"ssh-agent.sh: Configure ssh-agent startup and SSH key loading in your shell"},{"base":"yq","firstLine":"yq.sh: Download and install yq, the command-line YAML processor"}] as { base: string; firstLine: string }[];

export default function List() {
  const [q, setQ] = useState("");
  const filtered = useMemo(() => {
    const query = q.toLowerCase().trim();
    if (!query) return data;
    return data.filter((item) => {
      return (
        item.base.toLowerCase().includes(query) ||
        item.firstLine.toLowerCase().includes(query)
      );
    });
  }, [q]);

  return (
    <section className="mx-auto max-w-6xl">
      <h2 className="mb-8 text-center text-3xl font-bold text-foreground">All Scripts</h2>
      <div style={{margin: "0 0 1rem"}}>
        <input
          aria-label="Search scripts"
          placeholder="Search by script or description..."
          value={q}
          onChange={(e) => setQ(e.target.value)}
          style={{
            width: "100%",
            padding: ".5rem .75rem",
            borderRadius: ".375rem",
            border: "1px solid #334155",
            background: "#0b1020",
            color: "#e5e7eb",
            outline: "none"
          }}
        />
      </div>
      <div style={{overflowX: 'auto'}}>
        <table style={{width: '100%', borderCollapse: 'collapse'}}>
          <thead>
            <tr>
              <th style={{textAlign: 'left', padding: '.5rem', borderBottom: '1px solid #334155'}}>Script</th>
              <th style={{textAlign: 'left', padding: '.5rem', borderBottom: '1px solid #334155'}}>Description</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map(({ base, firstLine }) => (
              <tr key={base}>
                <td style={{verticalAlign: 'top', padding: '.5rem', borderBottom: '1px solid #1f2937'}}>
                  <Link to={"/scripts/" + base}>{base}.sh</Link>
                </td>
                <td style={{verticalAlign: 'top', padding: '.5rem', borderBottom: '1px solid #1f2937'}}>
                  {firstLine}
                </td>
              </tr>
            ))}
            {filtered.length === 0 && (
              <tr>
                <td colSpan={2} style={{padding: '.75rem', color: '#94a3b8'}}>No matches.</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </section>
  );
}
