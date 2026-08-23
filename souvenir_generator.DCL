Project : dialog {
  key = "Project";
  label = "Design Your Unique Souvenir";
  style = "font-size:16pt;";

  : text {
    key = "Title";
    label = "Create a memorable souvernir:";
    style = "font-size:14pt;";
  }

  : spacer {
    height = 1;
  }

  : edit_box {
    key = "base_diam";
    label = "Choose the souvenir size (mm):";
    width = 5;
    style = "font-size:14pt;";
  }

  : spacer {
    height = 1;
  }

  : radio_row {
    key = "scene_type";
    label = "Select a theme for your souvenir:";
    style = "font-size:14pt;";

    : radio_button {
      key = "forest";
      label = "Silent Forest";
      style = "font-size:14pt;";
    }
    : radio_button {
      key = "town";
      label = "Modern City";
      style = "font-size:14pt;";
    }
  }

  : spacer {
    height = 1;
  }

  ok_only;
}
