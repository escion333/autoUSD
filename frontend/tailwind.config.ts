import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./src/pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/components/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/app/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        // Primary palette
        primary: {
          DEFAULT: "#4CA8A1",
          hover: "#3E8F89",
          subtle: "#E8F6F5",
        },
        // Secondary palette
        secondary: {
          DEFAULT: "#D6C7A1",
          hover: "#C4B48C",
        },
        // Accent colors
        mist: "#EAEFF2",
        // Background colors
        background: "#F9FBFB",
        surface: "#F3FAF8",
        // Border colors
        border: {
          DEFAULT: "#D9E6E3",
          subtle: "rgba(217, 230, 227, 0.5)",
        },
        // Text colors
        text: {
          title: "#0F1416",
          body: "#1C1C1C",
          muted: "#5C6B6A",
        },
        // Status colors
        success: {
          DEFAULT: "#1AAE6F",
          subtle: "#E5F7EF",
        },
        warning: {
          DEFAULT: "#E6A700",
          subtle: "#FFF8E1",
        },
        error: {
          DEFAULT: "#E25555",
          subtle: "#FFEBEB",
        },
        // Interactive states
        focus: "#72D1CB",
        white: "#FFFFFF",
      },
      borderRadius: {
        xs: "6px",
        sm: "10px",
        md: "14px",
        lg: "18px",
        xl: "24px",
        pill: "9999px",
      },
      boxShadow: {
        sm: "0 1px 2px rgba(15, 20, 22, 0.06)",
        md: "0 8px 24px rgba(15, 20, 22, 0.08)",
        lg: "0 16px 40px rgba(15, 20, 22, 0.10)",
        glass: "inset 0 0 0 1px rgba(76, 168, 161, 0.25)",
        focus: "0 0 0 3px rgba(114, 209, 203, 0.5)",
      },
      fontFamily: {
        heading: ["Poppins", "ui-sans-serif", "system-ui", "-apple-system", "sans-serif"],
        body: ["Inter", "ui-sans-serif", "system-ui", "-apple-system", "sans-serif"],
        mono: ["ui-monospace", "SFMono-Regular", "Consolas", "monospace"],
      },
      spacing: {
        18: "4.5rem",
        22: "5.5rem",
      },
      animation: {
        "fade-in": "fadeIn 0.5s ease-out",
        "slide-up": "slideUp 0.3s ease-out",
        "value-pulse": "valuePulse 350ms ease-out",
        "skeleton": "skeleton 1.2s linear infinite",
      },
      keyframes: {
        fadeIn: {
          "0%": { opacity: "0" },
          "100%": { opacity: "1" },
        },
        slideUp: {
          "0%": { transform: "translateY(10px)", opacity: "0" },
          "100%": { transform: "translateY(0)", opacity: "1" },
        },
        valuePulse: {
          "0%, 100%": { transform: "scale(1)" },
          "50%": { transform: "scale(1.12)" },
        },
        skeleton: {
          "0%": { backgroundPosition: "100% 0" },
          "100%": { backgroundPosition: "-100% 0" },
        },
      },
      transitionDuration: {
        fast: "200ms",
        normal: "300ms",
        slow: "500ms",
      },
    },
  },
  plugins: [
    function({ addUtilities, theme }: any) {
      const newUtilities = {
        ".focus-ring": {
          outline: "none",
          boxShadow: theme("boxShadow.focus"),
        },
        ".card": {
          background: theme("colors.surface"),
          border: `1px solid ${theme("colors.border.DEFAULT")}`,
          borderRadius: theme("borderRadius.lg"),
          boxShadow: theme("boxShadow.sm"),
        },
        ".stat": {
          background: theme("colors.surface"),
          border: `1px solid ${theme("colors.border.DEFAULT")}`,
          borderRadius: theme("borderRadius.lg"),
          boxShadow: theme("boxShadow.sm"),
          padding: "1.25rem",
        },
        ".skeleton": {
          background: `linear-gradient(90deg, ${theme("colors.mist")} 25%, ${theme("colors.surface")} 37%, ${theme("colors.mist")} 63%)`,
          backgroundSize: "400% 100%",
          animation: theme("animation.skeleton"),
        },
      };
      addUtilities(newUtilities);
    },
  ],
};

export default config;