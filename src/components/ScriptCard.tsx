import { Card } from "@/components/ui/card";
import { LucideIcon } from "lucide-react";

interface ScriptCardProps {
  icon: LucideIcon;
  title: string;
  description: string;
  command: string;
}

export const ScriptCard = ({ icon: Icon, title, description, command }: ScriptCardProps) => {
  return (
    <Card className="group relative overflow-hidden border-border bg-gradient-to-br from-card to-secondary p-6 transition-all hover:border-accent hover:shadow-[var(--shadow-glow)]">
      <div className="relative z-10">
        <div className="mb-4 inline-flex h-12 w-12 items-center justify-center rounded-lg bg-accent/10 text-accent transition-all group-hover:bg-accent group-hover:text-accent-foreground">
          <Icon className="h-6 w-6" />
        </div>
        <h3 className="mb-2 text-xl font-semibold text-foreground">{title}</h3>
        <p className="mb-4 text-sm text-muted-foreground">{description}</p>
        <code className="block rounded bg-background/50 p-3 font-mono text-xs text-accent">
          load.sh {command}
        </code>
      </div>
      <div className="absolute inset-0 bg-gradient-to-br from-accent/5 to-transparent opacity-0 transition-opacity group-hover:opacity-100" />
    </Card>
  );
};
