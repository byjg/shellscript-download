import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { CopyButton } from "@/components/InstallCommand.tsx";

const SITE = "https://shellscript.download";

// The badge of a script (dist/badge/<script>.svg, written by generate-static-pages.mjs), and
// what to paste in a README to show it, linked to the page of the script
export const BadgeEmbed = ({ script }: { script: string }) => {
  const badge = `${SITE}/badge/${script}.svg`;
  const page = `${SITE}/scripts/${script}`;
  const alt = `shellscript.download: load.sh ${script}`;
  const variants = [
    { label: "Markdown", code: `[![${alt}](${badge})](${page})` },
    { label: "HTML", code: `<a href="${page}"><img src="${badge}" alt="${alt}"></a>` },
  ];

  return (
    <div className="mt-4 rounded-lg border border-border bg-card p-6 shadow-lg">
      <Tabs defaultValue={variants[0].label}>
        <div className="mb-3 flex items-center justify-between gap-3">
          <span className="text-sm font-medium text-muted-foreground">Add this badge to your README</span>
          <TabsList className="h-8">
            {variants.map(({ label }) => (
              <TabsTrigger key={label} value={label} className="px-3 py-1 font-mono text-xs">
                {label}
              </TabsTrigger>
            ))}
          </TabsList>
        </div>
        <img src={`/badge/${script}.svg`} alt={alt} className="mb-3" />
        {variants.map(({ label, code }) => (
          <TabsContent key={label} value={label} className="mt-0 flex items-center gap-3">
            <code className="block min-w-0 flex-1 break-all font-mono text-sm text-foreground">
              {code}
            </code>
            <CopyButton text={code} />
          </TabsContent>
        ))}
      </Tabs>
    </div>
  );
};
