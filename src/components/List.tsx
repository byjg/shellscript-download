// ------------------------------------------------------------------------------------
// Auto-generated — List component built from public/scripts headers. Do not edit.
// ------------------------------------------------------------------------------------

import { useMemo, useState } from "react";
import { Link } from "react-router-dom";

export default function List() {
  const data = [{"base":"docker","firstLine":"docker.sh: Install the Docker Engine on Linux in a safe, idempotent, shell-friendly way"},{"base":"load","firstLine":"load.sh: Fetch a script from https://shellscript.download, cache it locally,"},{"base":"maven","firstLine":"maven.sh: Download and install Apache Maven"},{"base":"node-docker","firstLine":"node-docker.sh: Create Docker-backed Node.js launchers (node, npm, npx, yarn)"},{"base":"nvm","firstLine":"nvm.sh: Install Node Version Manager (NVM) and set up a shell init snippet"},{"base":"php-docker","firstLine":"php-docker.sh: Create Docker-backed php and composer launchers"},{"base":"php-rest-api","firstLine":"php-rest-api.sh: Install byjg/rest-reference-architecture in unattended mode"}] as { base: string; firstLine: string }[];
  const [q, setQ] = useState("");
  const filtered = useMemo(() => {
    const query = q.toLowerCase().trim();
    if (!query) return data;
    return data.filter((item) => {
      return (
        item.base.toLowerCase().includes(query) ||
        item.firstLine.toLowerCase().includes(query)
      );
    });
  }, [q, data]);

  return (
    <section className="mx-auto max-w-6xl">
      <h2 className="mb-8 text-center text-3xl font-bold text-foreground">All Scripts</h2>
      <div style={{margin: "0 0 1rem"}}>
        <input
          aria-label="Search scripts"
          placeholder="Search by script or description..."
          value={q}
          onChange={(e) => setQ(e.target.value)}
          style={{
            width: "100%",
            padding: ".5rem .75rem",
            borderRadius: ".375rem",
            border: "1px solid #334155",
            background: "#0b1020",
            color: "#e5e7eb",
            outline: "none"
          }}
        />
      </div>
      <div style={{overflowX: 'auto'}}>
        <table style={{width: '100%', borderCollapse: 'collapse'}}>
          <thead>
            <tr>
              <th style={{textAlign: 'left', padding: '.5rem', borderBottom: '1px solid #334155'}}>Script</th>
              <th style={{textAlign: 'left', padding: '.5rem', borderBottom: '1px solid #334155'}}>Description</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map(({ base, firstLine }) => (
              <tr key={base}>
                <td style={{verticalAlign: 'top', padding: '.5rem', borderBottom: '1px solid #1f2937'}}>
                  <Link to={"/scripts/" + base}>{base}.sh</Link>
                </td>
                <td style={{verticalAlign: 'top', padding: '.5rem', borderBottom: '1px solid #1f2937'}}>
                  {firstLine}
                </td>
              </tr>
            ))}
            {filtered.length === 0 && (
              <tr>
                <td colSpan={2} style={{padding: '.75rem', color: '#94a3b8'}}>No matches.</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </section>
  );
}
