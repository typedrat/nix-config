# Post-mortem view for a machine that stopped responding. Every panel shares one
# time axis, so a stall can be read against what the kernel was saying while it
# happened, and the logs sit last because they are where you look once the graphs
# have said roughly where to look.
let
  promDs = {
    type = "prometheus";
    uid = "prometheus";
  };

  lokiDs = {
    type = "loki";
    uid = "loki";
  };

  # Grafana colours series by their position in the response, so a query that
  # returns a different set repaints whatever survived. Pinning by name keeps a
  # colour attached to the thing it identifies.
  fixed = name: color: {
    matcher = {
      id = "byName";
      options = name;
    };
    properties = [
      {
        id = "color";
        value = {
          mode = "fixed";
          fixedColor = color;
        };
      }
    ];
  };

  target = refId: expr: legendFormat: {
    inherit refId expr legendFormat;
    datasource = promDs;
    editorMode = "code";
    range = true;
  };

  graph = {
    title,
    description,
    gridPos,
    targets,
    unit ? "short",
    overrides ? [],
    min ? 0,
  }: {
    inherit title description gridPos targets;
    type = "timeseries";
    datasource = promDs;
    fieldConfig = {
      defaults = {
        inherit unit min;
        custom = {
          lineWidth = 2;
          fillOpacity = 8;
          showPoints = "never";
          drawStyle = "line";
          gradientMode = "none";
          axisBorderShow = false;
          pointSize = 8;
        };
      };
      inherit overrides;
    };
    options = {
      legend = {
        showLegend = true;
        displayMode = "list";
        placement = "bottom";
        calcs = [];
      };
      tooltip = {
        mode = "multi";
        sort = "desc";
      };
    };
  };

  logPanel = {
    title,
    description,
    gridPos,
    expr,
  }: {
    inherit title description gridPos;
    type = "logs";
    datasource = lokiDs;
    targets = [
      {
        refId = "A";
        inherit expr;
        datasource = lokiDs;
        queryType = "range";
      }
    ];
    options = {
      showTime = true;
      wrapLogMessage = true;
      prettifyLogMessage = false;
      enableLogDetails = true;
      sortOrder = "Descending";
    };
  };

  row = title: y: {
    inherit title;
    type = "row";
    collapsed = false;
    panels = [];
    gridPos = {
      h = 1;
      w = 24;
      x = 0;
      inherit y;
    };
  };

  pos = x: y: w: h: {inherit x y w h;};
in {
  uid = "lock-ups";
  title = "Lock-up forensics";
  tags = ["generated"];
  timezone = "browser";
  schemaVersion = 39;
  editable = true;
  refresh = "30s";
  graphTooltip = 1; # shared crosshair: the whole point is lining panels up

  time = {
    from = "now-6h";
    to = "now";
  };

  templating.list = [
    {
      name = "instance";
      label = "Host";
      type = "query";
      datasource = promDs;
      query = "label_values(node_load1, instance)";
      refresh = 1;
      sort = 1;
      current = {
        text = "ulysses";
        value = "ulysses";
      };
    }
  ];

  panels = [
    (row "Stall signals" 0)

    (graph {
      title = "Full stall — every task blocked";
      description = ''
        PSI "full": the share of time *nothing* could run because everyone was
        waiting on the same resource. Sustained time above zero here is the
        clearest sign a machine is seizing rather than merely busy.
      '';
      gridPos = pos 0 1 12 8;
      unit = "percentunit";
      targets = [
        (target "A" ''rate(node_pressure_io_stalled_seconds_total{instance="$instance"}[$__rate_interval])'' "io")
        (target "B" ''rate(node_pressure_memory_stalled_seconds_total{instance="$instance"}[$__rate_interval])'' "memory")
        (target "C" ''rate(node_pressure_irq_stalled_seconds_total{instance="$instance"}[$__rate_interval])'' "irq")
      ];
      overrides = [
        (fixed "io" "orange")
        (fixed "memory" "purple")
        (fixed "irq" "blue")
      ];
    })

    (graph {
      title = "Some pressure — at least one task blocked";
      description = ''
        PSI "some". Rises well before a full stall and is normal under load, so
        read it for the shape of the run-up rather than as a fault on its own.
      '';
      gridPos = pos 12 1 12 8;
      unit = "percentunit";
      targets = [
        (target "A" ''rate(node_pressure_cpu_waiting_seconds_total{instance="$instance"}[$__rate_interval])'' "cpu")
        (target "B" ''rate(node_pressure_io_waiting_seconds_total{instance="$instance"}[$__rate_interval])'' "io")
        (target "C" ''rate(node_pressure_memory_waiting_seconds_total{instance="$instance"}[$__rate_interval])'' "memory")
      ];
      overrides = [
        (fixed "cpu" "blue")
        (fixed "io" "orange")
        (fixed "memory" "purple")
      ];
    })

    (graph {
      title = "Processes blocked vs running";
      description = ''
        Blocked counts tasks in uninterruptible sleep. A climbing floor that
        never drains is the signature of tasks stuck on a device that has
        stopped answering.
      '';
      gridPos = pos 0 9 12 8;
      targets = [
        (target "A" ''node_procs_blocked{instance="$instance"}'' "blocked")
        (target "B" ''node_procs_running{instance="$instance"}'' "running")
      ];
      overrides = [
        (fixed "blocked" "red")
        (fixed "running" "green")
      ];
    })

    (graph {
      title = "Load average";
      description = ''
        On Linux load counts uninterruptible sleepers too, so it climbs when
        tasks are stuck even while the CPUs sit idle. Read it next to the
        blocked count, not on its own.
      '';
      gridPos = pos 12 9 12 8;
      targets = [
        (target "A" ''node_load1{instance="$instance"}'' "1m")
        (target "B" ''node_load5{instance="$instance"}'' "5m")
        (target "C" ''node_load15{instance="$instance"}'' "15m")
      ];
      overrides = [
        (fixed "1m" "blue")
        (fixed "5m" "purple")
        (fixed "15m" "green")
      ];
    })

    (row "Memory" 17)

    (graph {
      title = "Available memory";
      description = "What the kernel believes it could hand out without swapping.";
      gridPos = pos 0 18 8 8;
      unit = "bytes";
      targets = [
        (target "A" ''node_memory_MemAvailable_bytes{instance="$instance"}'' "available")
      ];
      overrides = [(fixed "available" "blue")];
    })

    (graph {
      title = "Free blocks by order";
      description = ''
        Buddy allocator free lists. Plenty of free memory can still fail a
        high-order allocation once the large orders drain to zero, and that
        failure mode stalls rather than reporting itself.
      '';
      gridPos = pos 8 18 8 8;
      targets = [
        (target "A" ''sum by (size) (node_buddyinfo_blocks{instance="$instance"})'' "order {{size}}")
      ];
    })

    (graph {
      title = "Major page faults";
      description = "Faults that had to reach storage. A spike alongside IO pressure points at thrashing.";
      gridPos = pos 16 18 8 8;
      unit = "ops";
      targets = [
        (target "A" ''rate(node_vmstat_pgmajfault{instance="$instance"}[$__rate_interval])'' "major faults")
      ];
      overrides = [(fixed "major faults" "orange")];
    })

    (row "Hardware" 26)

    (graph {
      title = "Temperatures";
      description = ''
        Hottest sensor per chip rather than every sensor, which on this hardware
        is eighteen series and an unreadable legend. NVMe chips are left out
        because SMART already reports those disks.
      '';
      gridPos = pos 0 27 12 8;
      unit = "celsius";
      min = null;
      targets = [
        (target "A" ''max by (chip) (node_hwmon_temp_celsius{instance="$instance", chip!~"nvme.*"})'' "{{chip}}")
        (target "B" ''smartctl_device_temperature{instance="$instance",temperature_type="current"}'' "disk {{device}}")
      ];
    })

    (graph {
      title = "Interrupt rate";
      description = "A runaway device shows up here as a step change well before anything else notices.";
      gridPos = pos 12 27 12 8;
      unit = "ops";
      targets = [
        (target "A" ''rate(node_intr_total{instance="$instance"}[$__rate_interval])'' "interrupts")
      ];
      overrides = [(fixed "interrupts" "yellow")];
    })

    (row "Logs" 35)

    (logPanel {
      title = "Kernel — netconsole";
      description = ''
        Sent from netpoll, so it keeps reporting after userspace has stopped.
        Lines read `prival,sequence,timestamp,flags;message`; a jump in the
        sequence number is a dropped datagram rather than a quiet moment.
      '';
      gridPos = pos 0 36 12 10;
      expr = ''{job="netconsole"}'';
    })

    (logPanel {
      title = "Journal — syslog";
      description = "The full journal, which carries more than the console does but stops the moment the machine does.";
      gridPos = pos 12 36 12 10;
      expr = ''{job="syslog", hostname="$instance"}'';
    })
  ];
}
