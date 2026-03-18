import { createServer } from "openserver";

const server = createServer({
  schemas: [],
  transport: "http",
  dataDir: ".fractal",
  viewsDir: "src/views",
  port: 3333,
});

await server.start();
