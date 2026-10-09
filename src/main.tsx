import { createRoot } from "react-dom/client";
import App from "./App.tsx";
import "@fontsource-variable/ubuntu-sans";
import "@fontsource-variable/ubuntu-sans-mono";
import "./index.css";

createRoot(document.getElementById("root")!).render(<App />);
