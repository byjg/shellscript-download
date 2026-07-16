import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { CheckCircle2, Info, XCircle } from "lucide-react";

const Yes = () => <CheckCircle2 className="mt-0.5 h-4 w-4 shrink-0 text-accent" />;
const Partial = () => <Info className="mt-0.5 h-4 w-4 shrink-0 text-yellow-500" />;
const No = () => <XCircle className="mt-0.5 h-4 w-4 shrink-0 text-destructive" />;

const Row = ({ icon, label, children }: { icon: React.ReactNode; label: string; children: React.ReactNode }) => (
  <li className="flex items-start gap-2 text-sm">
    {icon}
    <span>
      <span className="font-mono font-medium text-foreground">{label}</span>{" "}
      <span className="text-muted-foreground">— {children}</span>
    </span>
  </li>
);

const Section = ({ title, children }: { title: string; children: React.ReactNode }) => (
  <div>
    <h3 className="mb-2 text-sm font-semibold text-foreground">{title}</h3>
    <ul className="space-y-1.5">{children}</ul>
  </div>
);

export const CompatibilityModal = () => (
  <Dialog>
    <DialogTrigger asChild>
      <button className="text-sm text-accent underline-offset-4 transition-colors hover:text-accent/80 hover:underline">
        Check compatibility
      </button>
    </DialogTrigger>
    <DialogContent className="max-h-[85vh] max-w-lg overflow-y-auto">
      <DialogHeader>
        <DialogTitle>Compatibility</DialogTitle>
        <DialogDescription>
          Where the installer and the scripts run. All scripts need <code className="font-mono">curl</code> or{" "}
          <code className="font-mono">wget</code>, plus <code className="font-mono">bash</code> installed.
        </DialogDescription>
      </DialogHeader>
      <div className="space-y-5">
        <Section title="Shells">
          <Row icon={<Yes />} label="bash">fully supported, including tab completion</Row>
          <Row icon={<Yes />} label="zsh">supported as your login shell; scripts themselves run in bash</Row>
          <Row icon={<Partial />} label="sh / dash / ash">the installer works, but the scripts require bash to be installed</Row>
          <Row icon={<No />} label="fish">not supported</Row>
        </Section>
        <Section title="Linux distributions">
          <Row icon={<Yes />} label="Ubuntu / Debian">and derivatives, including WSL2</Row>
          <Row icon={<Yes />} label="RHEL / Fedora / Rocky / Alma">full support</Row>
          <Row icon={<Yes />} label="Arch / openSUSE">full support</Row>
          <Row icon={<Partial />} label="Alpine / BusyBox">
            install bash first (<code className="font-mono">apk add bash</code>). Java installers ship glibc builds, which
            need <code className="font-mono">gcompat</code> on musl — prefer the Docker-backed scripts there
          </Row>
        </Section>
        <Section title="CPU architectures">
          <Row icon={<Yes />} label="x86_64">all scripts</Row>
          <Row icon={<Yes />} label="aarch64 (ARM64)">
            supported — Java scripts pick the matching build automatically (Raspberry Pi, AWS Graviton, …)
          </Row>
          <Row icon={<Partial />} label="other">
            Java installers refuse with a clear error; Docker-backed scripts follow your Docker platform
          </Row>
        </Section>
        <p className="text-xs text-muted-foreground">
          Some scripts need extra tools, e.g. <code className="font-mono">tar</code>,{" "}
          <code className="font-mono">jq</code> (java-temurin), <code className="font-mono">docker</code> (php-docker,
          node-docker) or <code className="font-mono">sudo</code> (docker). Each script's page lists its usage.
        </p>
      </div>
    </DialogContent>
  </Dialog>
);
