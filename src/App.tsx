import { Toaster } from "@/components/ui/toaster";
import { Toaster as Sonner } from "@/components/ui/sonner";
import { TooltipProvider } from "@/components/ui/tooltip";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { useEffect } from "react";
import { BrowserRouter, Routes, Route, useLocation } from "react-router-dom";
import Index from "./pages/Index";
import InstallLoader from "./pages/InstallLoader";
import List from "./pages/List";
import NotFound from "./pages/NotFound";
import { scriptRoutes } from "./generated/scriptRoutes";

const queryClient = new QueryClient();

// The title of index.html. A script's page is served with its own title (scripts/generate-static-pages.mjs),
// which would otherwise stay on the tab after navigating away from it.
const HOME_TITLE = "shellscript.download - Quick Install Shell Scripts for Linux";

const DocumentTitle = () => {
  const { pathname } = useLocation();
  useEffect(() => {
    const script = pathname.match(/^\/scripts\/([^/]+)$/)?.[1];
    document.title = script ? `${script}.sh - shellscript.download` : HOME_TITLE;
  }, [pathname]);
  return null;
};

const validateRoute = (route) => {
    // Add validation logic here
    return true;
};

const App = () => (
  <QueryClientProvider client={queryClient}>
    <TooltipProvider>
      <Toaster />
      <Sonner />
      <BrowserRouter>
        <DocumentTitle />
        <Routes>
          <Route path="/" element={<Index />} />
          {/*<Route path="/list" element={<List />} />*/}
          {scriptRoutes
            .filter(validateRoute)
            .map((r) => (
              <Route key={r.path} path={r.path} element={r.element} />
            ))}
          {/*<Route path="/install/loader" element={<InstallLoader />} />*/}
          {/* ADD ALL CUSTOM ROUTES ABOVE THE CATCH-ALL "*" ROUTE */}
          <Route path="*" element={<NotFound />} />
        </Routes>
      </BrowserRouter>
    </TooltipProvider>
  </QueryClientProvider>
);

export default App;
