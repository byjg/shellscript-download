import { useLocation } from "react-router-dom";
import { useEffect } from "react";
import { Terminal } from "lucide-react";

const NotFound = () => {
  const location = useLocation();

  // Log the missing route for debugging/monitoring
  useEffect(() => {
    console.error("404 Error: User attempted to access non-existent route:", location.pathname);
  }, [location.pathname]);

  return (
    <div className="flex min-h-screen items-center justify-center bg-[var(--gradient-hero)]">
      <div className="text-center">
        <div className="mb-8 flex items-center justify-center gap-3">
          <Terminal className="h-16 w-16 text-accent" />
          <h1 className="text-8xl font-bold text-foreground">404</h1>
        </div>
        <p className="mb-8 text-xl text-muted-foreground">Oops! Page not found</p>
        <a
          href="/"
          className="inline-flex items-center gap-2 rounded-lg bg-accent px-6 py-3 font-medium text-accent-foreground transition-all hover:opacity-90"
        >
          <Terminal className="h-4 w-4" />
          Return to Home
        </a>
      </div>
    </div>
  );
};

export default NotFound;
