import { useMemo, useState } from "react";
import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { Input } from "@/components/ui/input";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Check, Copy } from "lucide-react";
import { toast } from "sonner";

interface SpecItem {
  kind: "arg" | "option";
  name: string; // positional name (e.g. "php_version") or flag (e.g. "--add")
  value?: string | null; // placeholder name when the option takes a value
  equals?: boolean; // --flag=value instead of --flag value
  required?: boolean;
  description?: string;
}

interface CommandSpec {
  prefix: string; // e.g. "load.sh php-docker"
  dashes: boolean; // whether args are passed after a "--" separator
  items: SpecItem[];
}

interface InstallCommandProps {
  // Basic command shown when no spec is provided, e.g. the curl installer line
  command?: string;
  // Optional command builder spec (auto-generated from the script's usage)
  spec?: CommandSpec;
  // Alternative commands shown as tabs (e.g. curl / wget)
  variants?: { label: string; command: string }[];
}

const CopyButton = ({ text }: { text: string }) => {
  const [copied, setCopied] = useState(false);

  const copyToClipboard = async () => {
    try {
      await navigator.clipboard.writeText(text);
      setCopied(true);
      toast.success("Copied to clipboard!");
      setTimeout(() => setCopied(false), 2000);
    } catch (err) {
      toast.error("Failed to copy");
    }
  };

  return (
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
  );
};

const CommandBuilder = ({ spec }: { spec: CommandSpec }) => {
  const [checked, setChecked] = useState<Record<string, boolean>>(() =>
    Object.fromEntries(spec.items.map((item) => [item.name, item.kind === "arg" || !!item.required])),
  );
  const [values, setValues] = useState<Record<string, string>>({});

  const setValue = (item: SpecItem, value: string) => {
    setValues((prev) => ({ ...prev, [item.name]: value }));
    // Typing a value implies the option is wanted
    if (value.trim() && !checked[item.name]) {
      setChecked((prev) => ({ ...prev, [item.name]: true }));
    }
  };

  const command = useMemo(() => {
    const parts = spec.items
      .map((item) => {
        if (!checked[item.name]) return null;
        const value = (values[item.name] || "").trim();
        if (item.kind === "arg") return value || `<${item.name}>`;
        if (!item.value) return item.name;
        const v = value || `<${item.value}>`;
        return item.equals ? `${item.name}=${v}` : `${item.name} ${v}`;
      })
      .filter(Boolean);
    if (parts.length === 0) return spec.prefix;
    return `${spec.prefix}${spec.dashes ? " --" : ""} ${parts.join(" ")}`;
  }, [spec, checked, values]);

  return (
    <>
      <div className="mb-4 space-y-2">
        {spec.items.map((item) => {
          const takesValue = item.kind === "arg" || !!item.value;
          const isRequired = item.kind === "arg" || !!item.required;
          return (
            <div key={item.name} className="flex items-center gap-3">
              <Checkbox
                id={`opt-${item.name}`}
                checked={!!checked[item.name]}
                disabled={isRequired}
                onCheckedChange={(state) => setChecked((prev) => ({ ...prev, [item.name]: state === true }))}
              />
              <label
                htmlFor={`opt-${item.name}`}
                className="w-40 shrink-0 truncate font-mono text-sm text-foreground"
                title={item.description || undefined}
              >
                {item.kind === "arg" ? `<${item.name}>` : item.name}
              </label>
              {takesValue ? (
                <Input
                  className="h-8 max-w-56 font-mono text-sm"
                  placeholder={item.kind === "arg" ? item.name : item.value || ""}
                  value={values[item.name] || ""}
                  onChange={(e) => setValue(item, e.target.value)}
                />
              ) : (
                <span className="hidden w-full max-w-56 sm:block" />
              )}
              <span className="hidden min-w-0 flex-1 truncate text-xs text-muted-foreground sm:block" title={item.description || undefined}>
                {item.description}
              </span>
            </div>
          );
        })}
      </div>
      <div className="flex items-center gap-3 border-t border-border pt-4">
        <code className="block min-w-0 flex-1 overflow-x-auto whitespace-nowrap font-mono text-sm text-foreground">
          {command}
        </code>
        <CopyButton text={command} />
      </div>
    </>
  );
};

export const InstallCommand = ({ command, spec, variants }: InstallCommandProps) => {
  const hasBuilder = !!spec && spec.items.length > 0;
  const hasVariants = !hasBuilder && !!variants && variants.length > 0;

  return (
    <div className="relative w-full">
      <div className="rounded-lg border border-border bg-card p-6 shadow-lg backdrop-blur-sm transition-all hover:shadow-[var(--shadow-glow)]">
        {hasVariants ? (
          <Tabs defaultValue={variants[0].label}>
            <div className="mb-3 flex items-center justify-between">
              <span className="text-sm font-medium text-muted-foreground">Installation Command</span>
              <TabsList className="h-8">
                {variants.map(({ label }) => (
                  <TabsTrigger key={label} value={label} className="px-3 py-1 font-mono text-xs">
                    {label}
                  </TabsTrigger>
                ))}
              </TabsList>
            </div>
            {variants.map(({ label, command: cmd }) => (
              <TabsContent key={label} value={label} className="mt-0 flex items-center gap-3">
                <code className="block min-w-0 flex-1 overflow-x-auto whitespace-nowrap font-mono text-sm text-foreground">
                  {cmd}
                </code>
                <CopyButton text={cmd} />
              </TabsContent>
            ))}
          </Tabs>
        ) : (
          <>
            <div className="mb-3 flex items-center justify-between">
              <span className="text-sm font-medium text-muted-foreground">Installation Command</span>
              {!hasBuilder && <CopyButton text={command || ""} />}
            </div>
            {hasBuilder ? (
              <CommandBuilder spec={spec} />
            ) : (
              <code className="block overflow-x-auto whitespace-nowrap font-mono text-sm text-foreground">
                {command}
              </code>
            )}
          </>
        )}
      </div>
    </div>
  );
};
