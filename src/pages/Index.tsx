import { Terminal, Container, Code, Server } from "lucide-react";
import { InstallCommand } from "@/components/InstallCommand";
import { InstructionStep } from "@/components/InstructionStep";
import { ScriptCard } from "@/components/ScriptCard";
import List from "@/components/List.tsx";

const Index = () => {
  const scripts = [
    {
      icon: Container,
      title: "Docker",
      description: "Install Docker and Docker Compose with all dependencies configured",
      command: "docker",
    },
    {
      icon: Code,
      title: "PHP Docker",
      description: "Complete PHP development environment with Docker containers",
      command: "php-docker",
    },
    {
      icon: Server,
      title: "PHP Rest API",
      description: "Reference architecture for building REST APIs with PHP",
      command: "php-rest-api",
    },
  ];

  return (
    <div className="min-h-screen bg-[var(--gradient-hero)]">
      <div className="container mx-auto px-4 py-16">
        <header className="mb-16 text-center">
          <div className="mb-6 inline-flex items-center gap-3 rounded-full border border-border bg-card/50 px-6 py-2 backdrop-blur-sm">
            <Terminal className="h-5 w-5 text-accent" />
            <span className="font-mono text-sm font-medium text-foreground">shellscript.download</span>
          </div>
          <h1 className="mb-6 text-5xl font-bold tracking-tight text-foreground md:text-6xl lg:text-7xl">
            Download & Run Scripts
            <span className="bg-gradient-to-r from-accent to-accent/70 bg-clip-text text-transparent"> Easily</span>
          </h1>
          <p className="mx-auto max-w-2xl text-lg text-muted-foreground">
            Download and run pre-defined shell scripts in your Linux system with a single command.
            No manual configuration needed.
          </p>
        </header>

        <section className="mb-20">
          <div className="mx-auto max-w-4xl space-y-12">
            <InstructionStep
              number="1"
              title="Copy the installation command"
              description="This command will download and install the script loader on your Linux system."
            />
            
            <div className="pl-[72px]">
              <InstallCommand command='/bin/bash -c "$(curl -fsSL https://shellscript.download/install/loader)"' />
            </div>

            <InstructionStep
              number="2"
              title="Run the command in your terminal"
              description="Open your terminal and paste the command. The loader will be installed automatically."
            />

            <InstructionStep
              number="3"
              title="Install your desired scripts"
              description="After installation, use load.sh followed by the script name to install any available script."
            />
          </div>
        </section>

        <section className="mb-20 mx-auto max-w-6xl">
          <h2 className="mb-8 text-center text-3xl font-bold text-foreground">Available Scripts</h2>
          <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
            {scripts.map((script) => (
              <ScriptCard key={script.command} {...script} />
            ))}
          </div>
        </section>

        <List />

        {/*<footer className="mt-20">*/}
        {/*  <p className="text-sm text-muted-foreground">*/}
        {/*  </p>*/}
        {/*</footer>*/}
      </div>
    </div>
  );
};

export default Index;
