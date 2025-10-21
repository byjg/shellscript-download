// ------------------------------------------------------------------------------------
// Auto-generated — /list page built from public/scripts headers. Do not edit.
// ------------------------------------------------------------------------------------

import React, { useMemo, useState } from "react";
import { Link } from "react-router-dom";

export default function List() {
  const data = [{"base":"docker","firstLine":"docker.sh: Install the Docker Engine on Linux in a safe, idempotent, shell-friendly way"},{"base":"load","firstLine":"load.sh: Download and optionally run shell scripts from shellscript.download"},{"base":"php-docker","firstLine":"php-docker.sh: Create Docker-backed php and composer launchers"}] as { base: string; firstLine: string }[];
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
    <div style={{maxWidth: 900, margin: "0 auto", padding: "2rem"}}>
      <Link to="/">← Home</Link>
      <h1 style={{fontSize: "1.5rem", margin: "0 0 1rem"}}>Available Scripts</h1>
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
    </div>
  );
}
