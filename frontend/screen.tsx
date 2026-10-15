import { api } from "@margince/frontend/api";
import { useT } from "@margince/frontend/app";
import {
  Badge,
  Button,
  Callout,
  Card,
  FactList,
  SectionHeader,
} from "@margince/frontend/design-system";
import { useQuery } from "@tanstack/react-query";
import { useState } from "react";

// Kept equal to Version in myextension.go by hand: the screen has no other way
// to say which release of the unit drew it.
const UNIT_VERSION = "0.3.1";

function usePing() {
  return useQuery({
    queryKey: ["ext", "my-extension", "ping"],
    queryFn: async () => {
      const { data, error } = await api.GET("/ext/my-extension/ping");
      if (error) throw error;
      return data;
    },
  });
}

// #/ext/my-extension: a demo page that shows the unit's screen was loaded,
// reached its own route, and runs React state like any core screen.
export default function MyExtensionScreen() {
  const t = useT();
  const ping = usePing();
  const [clicks, setClicks] = useState(0);
  const status = ping.isPending
    ? { tone: "info" as const, label: t("extMyExtension.status.asking") }
    : ping.data?.ok
      ? { tone: "success" as const, label: t("extMyExtension.status.answered") }
      : { tone: "danger" as const, label: t("extMyExtension.status.failed") };
  return (
    <div className="wrap narrow">
      <SectionHeader title={t("extMyExtension.title")} level={1} />
      <p>{t("extMyExtension.sub")}</p>
      <Callout tone="info" title={t("extMyExtension.loaded.title")}>
        {t("extMyExtension.loaded.body", { version: UNIT_VERSION })}
      </Callout>
      <Card>
        <SectionHeader title={t("extMyExtension.facts.title")} level={2} />
        <FactList
          facts={[
            { key: "unit", term: t("extMyExtension.facts.unit"), value: "my-extension" },
            { key: "version", term: t("extMyExtension.facts.version"), value: UNIT_VERSION },
            { key: "route", term: t("extMyExtension.facts.route"), value: "GET /v1/ext/my-extension/ping" },
            {
              key: "status",
              term: t("extMyExtension.facts.status"),
              value: <Badge tone={status.tone}>{status.label}</Badge>,
            },
          ]}
        />
        <Button variant="ghost" onClick={() => ping.refetch()}>
          {t("extMyExtension.pingAgain")}
        </Button>
      </Card>
      <Card>
        <SectionHeader title={t("extMyExtension.state.title")} level={2} />
        <p>{t("extMyExtension.state.count", { count: String(clicks) })}</p>
        <Button variant="primary" onClick={() => setClicks((n) => n + 1)}>
          {t("extMyExtension.state.click")}
        </Button>
      </Card>
    </div>
  );
}
