export const tokens = {
  colors: {
    // Primary palette
    primary: "#4CA8A1",
    primaryHover: "#3E8F89",
    primarySubtle: "#E8F6F5",
    
    // Secondary palette
    secondary: "#D6C7A1",
    secondaryHover: "#C4B48C",
    
    // Accent colors
    accentMist: "#EAEFF2",
    
    // Background colors
    background: "#F9FBFB",
    surface: "#F3FAF8",
    
    // Border colors
    border: "#D9E6E3",
    borderSubtle: "rgba(217, 230, 227, 0.5)",
    
    // Text colors
    textTitle: "#0F1416",
    textBody: "#1C1C1C",
    textMuted: "#5C6B6A",
    
    // Status colors
    success: "#1AAE6F",
    successSubtle: "#E5F7EF",
    warning: "#E6A700",
    warningSubtle: "#FFF8E1",
    error: "#E25555",
    errorSubtle: "#FFEBEB",
    
    // Interactive states
    focus: "#72D1CB",
    focusRing: "rgba(114, 209, 203, 0.5)",
    
    // Special colors
    white: "#FFFFFF",
    transparent: "transparent",
  },
  
  radii: {
    xs: "6px",
    sm: "10px",
    md: "14px",
    lg: "18px",
    xl: "24px",
    pill: "9999px",
  },
  
  shadows: {
    sm: "0 1px 2px rgba(15, 20, 22, 0.06)",
    md: "0 8px 24px rgba(15, 20, 22, 0.08)",
    lg: "0 16px 40px rgba(15, 20, 22, 0.10)",
    glassBorder: "inset 0 0 0 1px rgba(76, 168, 161, 0.25)",
    focus: "0 0 0 3px rgba(114, 209, 203, 0.5)",
  },
  
  spacing: {
    0: "0",
    1: "0.25rem",
    2: "0.5rem",
    3: "0.75rem",
    4: "1rem",
    5: "1.25rem",
    6: "1.5rem",
    7: "1.75rem",
    8: "2rem",
    9: "2.25rem",
    10: "2.5rem",
    11: "2.75rem",
    12: "3rem",
    14: "3.5rem",
    16: "4rem",
    18: "4.5rem",
    20: "5rem",
    22: "5.5rem",
    24: "6rem",
    28: "7rem",
    32: "8rem",
    36: "9rem",
    40: "10rem",
    44: "11rem",
    48: "12rem",
    52: "13rem",
    56: "14rem",
    60: "15rem",
    64: "16rem",
    72: "18rem",
    80: "20rem",
    96: "24rem",
  },
  
  typography: {
    heading: {
      family: "'Poppins', 'ui-sans-serif', 'system-ui', '-apple-system', 'BlinkMacSystemFont', 'Segoe UI', 'Roboto', 'Helvetica Neue', 'Arial', 'sans-serif'",
      weights: {
        semibold: 600,
        bold: 700,
      },
      tracking: {
        tight: "-0.02em",
        normal: "-0.01em",
      },
    },
    body: {
      family: "'Inter', 'ui-sans-serif', 'system-ui', '-apple-system', 'BlinkMacSystemFont', 'Segoe UI', 'Roboto', 'Helvetica Neue', 'Arial', 'sans-serif'",
      weights: {
        regular: 400,
        medium: 500,
        semibold: 600,
      },
      tracking: {
        normal: "0",
        wide: "0.01em",
      },
    },
    mono: {
      family: "'ui-monospace', 'SFMono-Regular', 'SF Mono', 'Consolas', 'Liberation Mono', 'Menlo', 'monospace'",
    },
  },
  
  fontSize: {
    xs: "0.75rem",    // 12px
    sm: "0.875rem",   // 14px
    base: "1rem",     // 16px
    lg: "1.125rem",   // 18px
    xl: "1.25rem",    // 20px
    "2xl": "1.5rem",  // 24px
    "3xl": "1.875rem", // 30px
    "4xl": "2.25rem", // 36px
    "5xl": "3rem",    // 48px
    "6xl": "3.75rem", // 60px
  },
  
  lineHeight: {
    none: "1",
    tight: "1.25",
    snug: "1.375",
    normal: "1.5",
    relaxed: "1.625",
    loose: "2",
  },
  
  
  animation: {
    duration: {
      instant: "0ms",
      fast: "200ms",
      normal: "300ms",
      slow: "500ms",
      slower: "700ms",
    },
    easing: {
      linear: "linear",
      easeIn: "cubic-bezier(0.4, 0, 1, 1)",
      easeOut: "cubic-bezier(0, 0, 0.2, 1)",
      easeInOut: "cubic-bezier(0.4, 0, 0.2, 1)",
      bounce: "cubic-bezier(0.68, -0.55, 0.265, 1.55)",
    },
  },
  
  zIndex: {
    base: 0,
    dropdown: 10,
    sticky: 20,
    fixed: 30,
    modalBackdrop: 40,
    modal: 50,
    popover: 60,
    tooltip: 70,
    notification: 80,
  },
  
  blur: {
    sm: "4px",
    md: "10px",
    lg: "20px",
    xl: "40px",
  },
} as const;

export type Tokens = typeof tokens;

// Helper function to generate CSS variables from tokens
export function generateCSSVariables(): string {
  const cssVars: string[] = [];
  
  // Colors
  Object.entries(tokens.colors).forEach(([key, value]) => {
    const varName = `--color-${key.replace(/([A-Z])/g, '-$1').toLowerCase()}`;
    cssVars.push(`${varName}: ${value};`);
  });
  
  // Radii
  Object.entries(tokens.radii).forEach(([key, value]) => {
    cssVars.push(`--radius-${key}: ${value};`);
  });
  
  // Shadows
  Object.entries(tokens.shadows).forEach(([key, value]) => {
    const varName = `--shadow-${key.replace(/([A-Z])/g, '-$1').toLowerCase()}`;
    cssVars.push(`${varName}: ${value};`);
  });
  
  return cssVars.join('\n  ');
}

// Export JSON version for design tools
export function exportTokensAsJSON(): string {
  return JSON.stringify(tokens, null, 2);
}