import { tokens } from "../../theme/tokens";

export const chartTheme = {
  colors: {
    primary: tokens.colors.primary,
    secondary: tokens.colors.secondary,
    success: tokens.colors.success,
    warning: tokens.colors.warning,
    error: tokens.colors.error,
    muted: tokens.colors.textMuted,
    grid: "rgba(0, 0, 0, 0.06)",
    axis: tokens.colors.textMuted,
    tooltip: {
      background: tokens.colors.white,
      border: tokens.colors.border,
      text: tokens.colors.textBody,
    },
  },
  
  line: {
    strokeWidth: 2,
    dot: {
      radius: 0,
      strokeWidth: 0,
    },
    activeDot: {
      radius: 4,
      strokeWidth: 2,
      stroke: tokens.colors.white,
    },
  },
  
  area: {
    fillOpacity: 0.15,
    strokeWidth: 2,
  },
  
  bar: {
    radius: [4, 4, 0, 0],
  },
  
  grid: {
    horizontal: true,
    vertical: false,
    strokeDasharray: "3 3",
  },
  
  axis: {
    fontSize: 12,
    fontFamily: tokens.typography.body.family,
    tick: {
      size: 4,
    },
  },
  
  tooltip: {
    borderRadius: tokens.radii.sm,
    padding: "8px 12px",
    fontSize: 13,
    fontFamily: tokens.typography.body.family,
    boxShadow: tokens.shadows.md,
  },
  
  legend: {
    fontSize: 13,
    fontFamily: tokens.typography.body.family,
    iconSize: 12,
    iconType: "rect" as const,
  },
  
  responsive: {
    container: {
      width: "100%",
      height: "100%",
      minHeight: 200,
    },
  },
};

// Recharts-specific defaults
export const rechartsDefaults = {
  margin: { top: 5, right: 5, bottom: 5, left: 5 },
  
  lineChart: {
    dot: false,
    strokeWidth: chartTheme.line.strokeWidth,
    type: "monotone" as const,
    animationDuration: 300,
  },
  
  areaChart: {
    strokeWidth: chartTheme.area.strokeWidth,
    fillOpacity: chartTheme.area.fillOpacity,
    type: "monotone" as const,
    animationDuration: 300,
  },
  
  barChart: {
    barGap: 4,
    barCategoryGap: "20%",
    animationDuration: 300,
  },
  
  cartesianGrid: {
    horizontal: chartTheme.grid.horizontal,
    vertical: chartTheme.grid.vertical,
    strokeDasharray: chartTheme.grid.strokeDasharray,
    stroke: chartTheme.colors.grid,
  },
  
  xAxis: {
    axisLine: false,
    tickLine: false,
    tick: {
      fontSize: chartTheme.axis.fontSize,
      fill: chartTheme.colors.axis,
    },
    padding: { left: 10, right: 10 },
  },
  
  yAxis: {
    axisLine: false,
    tickLine: false,
    tick: {
      fontSize: chartTheme.axis.fontSize,
      fill: chartTheme.colors.axis,
    },
    width: 40,
  },
  
  tooltip: {
    contentStyle: {
      backgroundColor: chartTheme.colors.tooltip.background,
      border: `1px solid ${chartTheme.colors.tooltip.border}`,
      borderRadius: chartTheme.tooltip.borderRadius,
      padding: chartTheme.tooltip.padding,
      fontSize: chartTheme.tooltip.fontSize,
      fontFamily: chartTheme.tooltip.fontFamily,
      boxShadow: chartTheme.tooltip.boxShadow,
    },
    labelStyle: {
      color: chartTheme.colors.tooltip.text,
      fontWeight: 600,
      marginBottom: 4,
    },
    itemStyle: {
      color: chartTheme.colors.tooltip.text,
      padding: "2px 0",
    },
    cursor: { fill: "transparent" },
  },
  
  legend: {
    iconSize: chartTheme.legend.iconSize,
    iconType: chartTheme.legend.iconType,
    wrapperStyle: {
      paddingTop: "20px",
      fontSize: chartTheme.legend.fontSize,
      fontFamily: chartTheme.legend.fontFamily,
    },
  },
  
  responsiveContainer: {
    width: "100%",
    height: "100%",
    minHeight: chartTheme.responsive.container.minHeight,
  },
};