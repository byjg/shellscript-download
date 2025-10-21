import { useLocation } from "react-router-dom";
import { useEffect } from "react";

const NotFound = () => {
  const location = useLocation();

  // Log the missing route for debugging/monitoring
  useEffect(() => {
    console.error(
      "404 Error: User attempted to access non-existent route:",
      location.pathname
    );
  }, [location.pathname]);

  // Hint to hosting/prerendering/search engines that this is a 404 page.
  // In client-side rendered apps, we cannot change the HTTP response after load,
  // but many platforms and crawlers respect these markers. We also expose a
  // window flag that servers/monitors can read if they inject scripts.
  useEffect(() => {
    let statusMeta: HTMLMetaElement | null = null;
    let robotsMeta: HTMLMetaElement | null = null;
    let prevRobotsContent: string | null = null;
    let createdRobots = false;

    // Set meta name="prerender-status-code" content="404"
    statusMeta = document.querySelector(
      'meta[name="prerender-status-code"]'
    ) as HTMLMetaElement | null;
    if (!statusMeta) {
      statusMeta = document.createElement("meta");
      statusMeta.setAttribute("name", "prerender-status-code");
      document.head.appendChild(statusMeta);
    }
    statusMeta.setAttribute("content", "404");

    // Ensure we don't index this page
    robotsMeta = document.querySelector(
      'meta[name="robots"]'
    ) as HTMLMetaElement | null;
    prevRobotsContent = robotsMeta?.getAttribute("content") ?? null;
    if (!robotsMeta) {
      robotsMeta = document.createElement("meta");
      robotsMeta.setAttribute("name", "robots");
      document.head.appendChild(robotsMeta);
      createdRobots = true;
    }
    robotsMeta.setAttribute("content", "noindex");

    // Optional flag for integrations
    (window as any).__STATUS_CODE__ = 404;

    return () => {
      if (statusMeta && statusMeta.parentNode) {
        document.head.removeChild(statusMeta);
      }
      if (robotsMeta) {
        if (prevRobotsContent && !createdRobots) {
          robotsMeta.setAttribute("content", prevRobotsContent);
        } else if (robotsMeta.parentNode) {
          document.head.removeChild(robotsMeta);
        }
      }
      try {
        delete (window as any).__STATUS_CODE__;
      } catch {}
    };
  }, [location.pathname]);

  return (
    <div className="flex min-h-screen items-center justify-center bg-gray-100">
      <div className="text-center">
        <h1 className="mb-4 text-4xl font-bold">404</h1>
        <p className="mb-4 text-xl text-gray-600">Oops! Page not found</p>
        <a href="/" className="text-blue-500 underline hover:text-blue-700">
          Return to Home
        </a>
      </div>
    </div>
  );
};

export default NotFound;
