
export interface ThemeVariables {
  [key: string]: string;
}

export interface ThemeState {
  variables: ThemeVariables;
  rawCss: string;
}
