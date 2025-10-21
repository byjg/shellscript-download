import { Toaster } from "@/components/ui/toaster";
import { Toaster as Sonner } from "@/components/ui/sonner";
import { TooltipProvider } from "@/components/ui/tooltip";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { BrowserRouter, Routes, Route } from "react-router-dom";
import Index from "./pages/Index";
import InstallLoader from "./pages/InstallLoader";
import List from "./pages/List";
import NotFound from "./pages/NotFound";
import { scriptRoutes } from "./generated/scriptRoutes";

const queryClient = new QueryClient();

const App = () => (
  <QueryClientProvider client={queryClient}>
    <TooltipProvider>
      <Toaster />
      <Sonner />
      <BrowserRouter>
        <Routes>
          <Route path="/" element={<Index />} />
          <Route path="/list" element={<List />} />
          {scriptRoutes.map((r) => (
            <Route key={r.path} path={r.path} element={r.element} />
          ))}
          {/*<Route path="/install/loader" element={<InstallLoader />} />*/}
          {/* ADD ALL CUSTOM ROUTES ABOVE THE CATCH-ALL "*" ROUTE */}
          {/*<Route path="*" element={<NotFound />} />*/}
        </Routes>
      </BrowserRouter>
    </TooltipProvider>
  </QueryClientProvider>
);

export default App;
