import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Check, Copy } from "lucide-react";
import { toast } from "sonner";

interface InstallCommandProps {
  // Optional script/command to run after installing the loader, e.g. "docker" or "php-docker"
  command?: string;
}

export const InstallCommand = ({ command }: InstallCommandProps) => {
  const [copied, setCopied] = useState(false);

  const copyToClipboard = async () => {
    try {
      await navigator.clipboard.writeText(command);
      setCopied(true);
      toast.success("Copied to clipboard!");
      setTimeout(() => setCopied(false), 2000);
    } catch (err) {
      toast.error("Failed to copy");
    }
  };

  return (
    <div className="relative w-full">
      <div className="rounded-lg border border-border bg-card p-6 shadow-lg backdrop-blur-sm transition-all hover:shadow-[var(--shadow-glow)]">
        <div className="mb-3 flex items-center justify-between">
          <span className="text-sm font-medium text-muted-foreground">Installation Command</span>
          <Button
            onClick={copyToClipboard}
            variant="secondary"
            size="sm"
            className="gap-2 transition-all hover:bg-accent hover:text-accent-foreground"
          >
            {copied ? (
              <>
                <Check className="h-4 w-4" />
                Copied
              </>
            ) : (
              <>
                <Copy className="h-4 w-4" />
                Copy
              </>
            )}
          </Button>
        </div>
        <code className="block overflow-x-auto whitespace-nowrap font-mono text-sm text-foreground">
          {command}
        </code>
      </div>
    </div>
  );
};
