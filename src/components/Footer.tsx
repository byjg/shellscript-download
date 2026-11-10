import { Github, Heart } from "lucide-react";

const link = "inline-flex items-center gap-1.5 text-muted-foreground transition-colors hover:text-accent";

// Who makes shellscript.download, on the home page and on the page of each script
export const Footer = () => (
  <footer className="mt-12 border-t border-border py-6 text-sm">
    <div className="flex flex-wrap items-center justify-center gap-x-4 gap-y-3">
      <a href="https://opensource.byjg.com" className={link}>
        Developed and maintained by
        <img src="/byjg-logo.svg" alt="ByJG" className="-my-4 h-14 w-14" />
      </a>
      <span aria-hidden="true" className="text-border">·</span>
      <a href="https://github.com/byjg/shellscript-download" className={link}>
        <Github aria-hidden="true" className="h-4 w-4" /> GitHub
      </a>
      <span aria-hidden="true" className="text-border">·</span>
      <a href="https://github.com/sponsors/byjg" className={link}>
        <Heart aria-hidden="true" className="h-4 w-4" /> Sponsor
      </a>
    </div>
  </footer>
);
