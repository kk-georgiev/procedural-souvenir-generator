;;; ============================================================================
;;; Global Variables
;;; ============================================================================

; Holds the most recent user input, allowing for reuse
(setq *last_input_data* nil)

; Stores the seed value used for random number generation
(setq *rand_seed* nil)

;;; ============================================================================
;;; Environment Setup
;;; ============================================================================

; Disable object snap to prevent automatic snapping to objects during drawing
(defun disable_onsnap ()
  (setvar "osmode" 0)
)

; Enable object snap to allow automatic snapping to objects during drawing
(defun enable_onsnap ()
  (setvar "osmode" 1)
)

; Turn off the grid display
(defun turn_off_grid ()
  (command "._grid" "off")
)

; Set the current view to SW Isometric
(defun switch_to_sw_isometric ()
  (command "._view" "swiso")
)

; Set visual style to 'Shades of Grey'
(defun switch_visual_style_to_shades_of_grey ()
  (command "._-visualstyles" "_c" "_g")
)

; Initialize the environment
(defun setup_environment ()
  (disable_onsnap)
  (turn_off_grid)
  (switch_to_sw_isometric)
  (switch_visual_style_to_shades_of_grey)
)

;;; ============================================================================
;;; Random Number Generation
;;; ============================================================================

; Initialize the random seed using the current date/time and last picked point
; Combines a base value derived from the date and a jitter value for variability
(defun init_random_seed ( / base jitter)
  (setq base (fix (* (getvar "DATE") 1000000)))
  (if (getvar "LASTPOINT")
    (setq jitter (fix (* 100 (car (reverse (getvar "LASTPOINT"))))))
    (setq jitter (fix (* 100 (rem base 17))))
  )
  (setq *rand_seed* (+ base jitter))
)

; Linear Congruential Generator implementation for pseudo-random integers
(defun my_random ( / )
  (if (not *rand_seed*)
    (init_random_seed)
  )
  (setq *rand_seed* (rem (+ (* *rand_seed* 1103515245) 12345) 2147483647))
  *rand_seed*
)

; Generate a floating-point number between 0.0 (inclusive) and 1.0 (exclusive)
(defun random_float ()
  (/ (float (my_random)) 2147483647.0)
)

; Generate an integer within the range [m_min, m_max) (inclusive min, exclusive max)
(defun random_in_range (m_min m_max)
  (+ m_min (fix (* (random_float) (- m_max m_min))))
)

;;; ============================================================================
;;; Input Handling
;;; ============================================================================

; Save current user input
(defun save_data (base_diam_str forest_sel town_sel)
  (setq *last_input_data*
    (list
      (cons 'base_diam base_diam_str)
      (cons 'forest forest_sel)
      (cons 'town town_sel)
    )
  )
)

; Retrieve last saved input data if available, otherwise return default values
(defun load_last_data ()
  (if *last_input_data*
    *last_input_data*
    (list
      (cons 'base_diam "250")
      (cons 'forest "1")
      (cons 'town "0")
    )
  )
)

; Run custom dialog for user input
(defun run_dialog (dcl_id base_diam_str forest_sel town_sel)
  (if (not (new_dialog "Project" dcl_id))
    (progn
      (prompt "\nError: Failed to load DCL file.")
      (princ)
    )
    (progn
      ; Fill dialog tiles with default values
      (set_tile "base_diam" base_diam_str)
      (set_tile "forest" forest_sel)
      (set_tile "town" town_sel)

      ; Define accept button behavior
      (action_tile "accept"
        "(progn
           (setq base_diam_str (get_tile \"base_diam\"))
           (setq base_diam_num (atof base_diam_str))
           (if (or (< base_diam_num 250) (> base_diam_num 500))
             (alert \"Base diameter must be between 250 and 500.\")
             (progn
               (setq forest_sel (get_tile \"forest\"))
               (setq town_sel (get_tile \"town\"))
               (done_dialog)
             )
           )
         )"
      )

      (start_dialog)
      (list base_diam_str base_diam_num forest_sel town_sel)
    )
  )
)

;;; ============================================================================
;;; Utility Functions
;;; ============================================================================

; Calculate Euclidean distance between 2 points
(defun dist (p1 p2)
  (sqrt (+ (expt (- (car p1) (car p2)) 2)
           (expt (- (cadr p1) (cadr p2)) 2)))
)

; Generate a random point within a circle of given radius at a fixed height
(defun point_in_circle (radius zheight)
  (setq theta (* 2 pi (random_float)))
  (setq r (* radius (sqrt (random_float))))
  (list (* r (cos theta)) (* r (sin theta)) zheight)
)

; Ensure a new point does not overlap others
(defun can_add_point (pt points / can_add pnts)
  (setq can_add T)
  (setq pnts points)
  (while (and can_add pnts)
    (if (< (dist pt (car pnts)) 50)
      (setq can_add nil)
    )
    (setq pnts (cdr pnts))
  )
  can_add
)

; Generate non-overlapping coordinates at a fixed height
(defun generate_coords (base_diam_num / radius num_points points pt attempts max_attempts zheight)
  (setq radius (/ base_diam_num 2.0))
  (setq zheight (/ base_diam_num 3.0))
  (setq num_points (random_in_range 10 50))
  (setq points '())
  (setq attempts 0)
  (setq max_attempts 1000)
  
  (while (and (< (length points) num_points) (< attempts max_attempts))
    (setq pt (point_in_circle radius zheight))
    (if (can_add_point pt points)
      (setq points (cons pt points))
    )
    (setq attempts (+ attempts 1))
  )
  
  points
)

; Return ceiling of float value
(defun my-ceiling (x)
  (if (= x (fix x))
    x
    (1+ (fix x))
  )
)

; Generate grid-based coordinates within circular area at a fixed height
(defun generate_grid (base_diam_num / radius num_points points spacing grid_size x y z px py)
  (setq radius (/ base_diam_num 2.0))
  (setq z (/ base_diam_num 3.0))
  (setq points '())

  (setq num_points (random_in_range 10 50))
  (setq grid_size (my-ceiling (sqrt num_points)))

  (setq spacing (/ (* 2 radius) (1- grid_size)))

  (setq y 0)
  (while (< y grid_size)
    (setq x 0)
    (while (< x grid_size)
      (setq px (- (* x spacing) radius))
      (setq py (- (* y spacing) radius))
      (if (<= (+ (* px px) (* py py)) (* radius radius))
          (setq points (cons (list px py z) points))
      )
      (setq x (1+ x))
    )
    (setq y (1+ y))
  )
  points
)

;;; ============================================================================
;;; Forest
;;; ============================================================================

; Create a tree model composed of a trunk and layered cone foliage
(defun create_tree (base_point base_diam_num scale_factor /
		    base_point_shifted
                    trunk_height trunk_radius tree_trunk trunk_top_point
                    foliage_height foliage_radius cone_positions cones
		    i z_pos radius)

  ; Shift base point upward
  (setq base_point_shifted
	 (list (car base_point)
	       (cadr base_point)
	       (/ base_diam_num 3.0)))

  ; Calculate trunk dimensions
  (setq trunk_height (* 3.0 scale_factor))
  (setq trunk_radius (* 1.0 scale_factor))
  (command "._cylinder" base_point_shifted trunk_radius trunk_height)
  (setq tree_trunk (entlast))

  ; Get top point of the trunk
  (setq trunk_top_point 
        (list (car base_point_shifted) (cadr base_point_shifted) (+ (caddr base_point_shifted) trunk_height)))

  ; Foliage base dimensions
  (setq foliage_height (* 4.5 scale_factor))
  (setq foliage_radius (* 4.0 scale_factor))

  ; Create 6 stacked cones for foliage, decreasing radius with height
  (setq cones '())
  (setq i 0)
  (repeat 6
    (setq z_pos (+ (caddr trunk_top_point) (* i 0.6 foliage_height)))
    (setq cone_pos (list (car trunk_top_point) (cadr trunk_top_point) z_pos))
    (setq radius (* foliage_radius (- 1 (* 0.15 i))))
    (command "._cone" cone_pos radius foliage_height)
    (setq cones (cons (entlast) cones))
    (setq i (1+ i))
  )

  ; Union trunk and all cone foliage parts
  (apply 'command (append '("._union" ) (cons tree_trunk (reverse cones)) '("")))
)

; Create a rock composed of multiple overlapping spheres
(defun create_rock (base_point base_diam_num scale_factor /
		    base_point_shifted
                    main_rock
		    part1 part2 part3
              	    part1_pos part2_pos part3_pos
                    part1_size part2_size part3_size)

  ; Shift base point upward
  (setq base_point_shifted
	 (list (car base_point)
	       (cadr base_point)
	       (/ base_diam_num (+ 3.0 (random_float)))))

  ; Define sizes for rock parts
  (setq part1_size (* 3.0 scale_factor))
  (setq part2_size (* 2.0 scale_factor))
  (setq part3_size (* 1.5 scale_factor))

  ; Create main rock body
  (command "._sphere" base_point_shifted part1_size)
  (setq main_rock (entlast))

  ; Define positions for smaller rock parts
  (setq part1_pos 
        (list (+ (car base_point_shifted) (* scale_factor 1.5)) 
              (+ (cadr base_point_shifted) (* scale_factor -1.0)) 
              (+ (caddr base_point_shifted) (* scale_factor 0.5))))
  (setq part2_pos 
        (list (+ (car base_point_shifted) (* scale_factor -1.5)) 
              (+ (cadr base_point_shifted) (* scale_factor 1.0)) 
              (+ (caddr base_point_shifted) (* scale_factor 0.3))))
  (setq part3_pos 
        (list (+ (car base_point_shifted) (* scale_factor 0.5)) 
              (+ (cadr base_point_shifted) (* scale_factor 1.5)) 
              (+ (caddr base_point_shifted) (* scale_factor -0.5))))

  ; Create smaller rock parts
  (command "._sphere" part1_pos part2_size)
  (setq part1 (entlast))

  (command "._sphere" part2_pos part3_size)
  (setq part2 (entlast))

  (command "._sphere" part3_pos (* 1.2 scale_factor))
  (setq part3 (entlast))

  ; Union all parts into one solid rock
  (command "._union" main_rock part1 part2 part3 "")
)

; Create a flower with stem, petals, and leaves
(defun create_flower (base_point base_diam_num scale_factor /
		      base_point_shifted
                      stem_height stem_radius
                      flower_stem flower_top_point
                      petal_body cut_box
                      petal_radius petal_height
                      petal_count theta_step i theta x y z petal_center petals
                      leaf1_base leaf1_tip leaf1
                      leaf2_base leaf2_tip leaf2)

  ; Shift base point upward
  (setq base_point_shifted
	 (list (car base_point)
	       (cadr base_point)
	       (/ base_diam_num 3.0)))

  ; Create the stem
  (setq stem_height (* 2.0 scale_factor))
  (setq stem_radius (* 0.15 scale_factor))
  (command "._cylinder" base_point_shifted stem_radius stem_height)
  (setq flower_stem (entlast))

  ; Top of the stem
  (setq flower_top_point 
        (list (car base_point_shifted) (cadr base_point_shifted) (+ (caddr base_point_shifted) stem_height)))

  ; Create petal base shape as a half sphere
  (command "._sphere" flower_top_point (* 0.95 scale_factor))
  (setq petal_body (entlast))

  (command "._box"
           (list (- (car flower_top_point) scale_factor)
                 (- (cadr flower_top_point) scale_factor)
                 (caddr flower_top_point))
           (list (+ (car flower_top_point) scale_factor)
                 (+ (cadr flower_top_point) scale_factor)
                 (+ (caddr flower_top_point) scale_factor)))
  (setq cut_box (entlast))
  (command "._subtract" petal_body "" cut_box "")

  ; Create petals as cones arranged around the top of stem
  (setq petal_radius (* 0.5 scale_factor))
  (setq petal_height (* 0.5 scale_factor))
  (setq petal_count 6)
  (setq theta_step (/ (* 2 pi) petal_count))
  (setq i 0)
  (setq petals '())
  (repeat petal_count
    (setq theta (* i theta_step))
    (setq x (+ (car flower_top_point) (* petal_radius (cos theta))))
    (setq y (+ (cadr flower_top_point) (* petal_radius (sin theta))))
    (setq z (caddr flower_top_point))
    (setq petal_center (list x y z))
    (command "._cone" petal_center (* 0.5 scale_factor) petal_height)
    (setq petals (cons (entlast) petals))
    (setq i (1+ i))
  )

  ; Create two leaves as cones on either side of stem
  (setq leaf1_base 
        (list (- (car base_point_shifted) stem_radius)
              (cadr base_point_shifted)
              (+ (caddr base_point_shifted) (* 0.4 scale_factor))))
  (setq leaf1_tip 
        (list (- (car base_point_shifted) (* 0.4 scale_factor))
              (cadr base_point_shifted)
              (+ (caddr base_point_shifted) (* 0.5 scale_factor))))
  (command "._cone" leaf1_tip (* 0.4 scale_factor) leaf1_base)
  (setq leaf1 (entlast))

  (setq leaf2_base 
        (list (+ (car base_point_shifted) stem_radius)
              (cadr base_point_shifted)
              (+ (caddr base_point_shifted) (* 0.9 scale_factor))))
  (setq leaf2_tip 
        (list (+ (car base_point_shifted) (* 0.4 scale_factor))
              (cadr base_point_shifted)
              (+ (caddr base_point_shifted) (* 0.8 scale_factor))))
  (command "._cone" leaf2_tip (* 0.4 scale_factor) leaf2_base)
  (setq leaf2 (entlast))

  ; Union all parts into one solid flower
  (apply 'command (append '("._union") (list flower_stem petal_body leaf1 leaf2) (reverse petals) '("")))
)

;;; ============================================================================
;;; Town
;;; ============================================================================

; Create a skyscraper model
(defun create_skyscraper (base_point base_diam_num scale_factor /
                           base_point_shifted
                           width depth height_factor height
                           win_width win_height extra_gap usable_height
                           win_step win_rows win_entities
                           building inset_box inset_entity)

  ; Calculate height factor based on base_diam_num
  (setq height_factor (/ 1.0 (* 2 scale_factor)))

  ; Define skyscraper dimensions using scale factor and height factor
  (setq height (* scale_factor (+ 20 (* 70 height_factor))))
  (setq width  (* scale_factor (+ 3.5 (* 5.5 height_factor))))
  (setq depth  (* scale_factor (+ 2.5 (* 2.25 height_factor))))

  ; Shift base point upward
  (setq base_point_shifted
	 (list (car base_point)
	       (cadr base_point)
	       (/ base_diam_num 3.0)))

  ; Create the main building block
  (command "._box" base_point_shifted
           (list (+ (car base_point_shifted) width)
                 (+ (cadr base_point_shifted) depth)
                 (+ (caddr base_point_shifted) height)))
  (setq building (entlast))

  ; Define window dimensions
  (setq win_width   (* scale_factor 0.3))
  (setq win_height  (* scale_factor 1.5))
  (setq extra_gap   (* scale_factor 2.0))
  (setq usable_height (- height extra_gap))
  (setq win_step (+ win_height (* scale_factor 0.2)))
  (setq win_rows (fix (/ usable_height win_step)))
  (setq win_entities '())

  ; Internal function to place windows on a specific building face
  (defun place_windows (face / i j
			       win_x win_y win_z win_cols
                               face_origin spacing_x win_depth
                               win_start win_end local_win)

    ; Set face origin and number of window columns based on building face
    (cond
      ((eq face 'front)
       (setq win_cols 3
             face_origin base_point_shifted
             win_depth (* 0.1 depth)))
      ((eq face 'back)
       (setq win_cols 3
             face_origin (list (car base_point_shifted)
                               (+ (cadr base_point_shifted) depth)
                               (caddr base_point_shifted))
             win_depth (* -0.1 depth)))
      ((eq face 'left)
       (setq win_cols 2
             face_origin base_point_shifted
             win_depth (* 0.1 width)))
      ((eq face 'right)
       (setq win_cols 2
             face_origin (list (+ (car base_point_shifted) width)
                               (cadr base_point_shifted)
                               (caddr base_point_shifted))
             win_depth (* -0.1 width))))

    ; Calculate horizontal spacing between windows
    (setq spacing_x (/ (- (if (or (eq face 'front) (eq face 'back)) width depth)
                          (* win_cols win_width))
                       (+ 1 win_cols)))
    
    ; Iterate through rows and columns to place windows
    (setq i 0)
    (while (< i win_rows)
      (setq j 0)
      (while (< j win_cols)
        (setq win_z (+ (caddr face_origin) extra_gap (* i win_step)))

	(setq offset (* scale_factor -0.1))

	; Determine window X and Y based on face
        (cond
          ((eq face 'front)
           (setq win_x (+ (car face_origin) spacing_x (* j (+ win_width spacing_x))))
           (setq win_y (+ (cadr face_origin) offset)))
          ((eq face 'back)
           (setq win_x (+ (car face_origin) spacing_x (* j (+ win_width spacing_x))))
           (setq win_y (- (cadr face_origin) offset)))
          ((eq face 'left)
           (setq win_x (+ (car face_origin) offset))
           (setq win_y (+ (cadr face_origin) spacing_x (* j (+ win_width spacing_x)))))
          ((eq face 'right)
           (setq win_x (- (car face_origin) offset))
           (setq win_y (+ (cadr face_origin) spacing_x (* j (+ win_width spacing_x))))))

	; Define window box start and end points
        (setq win_start (list win_x win_y win_z))
        (setq win_end
              (cond
                ((or (eq face 'front) (eq face 'back))
                 (list (+ win_x win_width)
                       (+ win_y win_depth)
                       (+ win_z win_height)))
                ((or (eq face 'left) (eq face 'right))
                 (list (+ win_x win_depth)
                       (+ win_y win_width)
                       (+ win_z win_height)))))

	; Create the window and subtract it from the building
        (command "._box" win_start win_end)
        (setq local_win (entlast))
        (if local_win
          (progn
            (command "._subtract" building "" local_win "")
            (setq win_entities (cons local_win win_entities))
          ))

        (setq j (1+ j))
      )
      (setq i (1+ i))
    )
  )

  ; Place windows on all four building faces
  (mapcar 'place_windows '(front back left right))

  ; Create a section at the top of the skyscraper
  (setq upper_inset (* scale_factor 0.2))
  (setq inset_height (* scale_factor 0.25))

  ; Define coordinates for the inset box
  (setq inset_box
        (list (+ (car base_point_shifted) upper_inset)
              (+ (cadr base_point_shifted) upper_inset)
              (+ (caddr base_point_shifted) (- height inset_height))))

  ; Create and subtract the top section
  (command "._box" inset_box
           (list (- (+ (car base_point_shifted) width) upper_inset)
                 (- (+ (cadr base_point_shifted) depth) upper_inset)
                 (+ (caddr base_point_shifted) height)))
  (setq inset_entity (entlast))
  (if inset_entity
    (command "._subtract" building "" inset_entity "")
  )
)

;;; ============================================================================
;;; Base
;;; ============================================================================

; Create the base
(defun create_base (base_diam_num / center bottom_radius height top_radius main_body tmp_cyl tmp_center new_cyl)
  (setq center (list 0 0 0))
  (setq bottom_radius (/ base_diam_num 1.4))
  (setq height (/ base_diam_num 3))
  (setq top_radius (+ (/ base_diam_num 2) (/ (/ base_diam_num 2) 6.25)))
  
  ; Create main body
  (command "._cone" center bottom_radius "_t" top_radius height)
  (setq main_body (entlast))

  ; Subtract cylinder to shape top
  (setq tmp_center (list 0 0 (- height (/ (/ base_diam_num 2) 12.0))))
  (command "._cylinder" tmp_center (- top_radius (/ (/ base_diam_num 2) 12.5)) height)
  (setq tmp_cyl (entlast))

  (command "._subtract" main_body "" tmp_cyl "")

  ; Add top flat platform
  (command "._cylinder" tmp_center (/ base_diam_num 2) (/ (/ base_diam_num 2) 12.5))
  (setq new_cyl (entlast))

  (command "._union" main_body new_cyl "")
)

;;; ============================================================================
;;; Main Command Function
;;; ============================================================================

(defun c:Project ( / dcl_id input_data base_diam_str base_diam_num
                     forest_sel town_sel scene_num)

  ; Load DCL file
  (setq dcl_id (load_dialog "C:/VLISP/DCL/PROJECT.DCL"))
  (if (not dcl_id)
    (progn
      (prompt "\nError: Failed to load DCL file.")
      (princ)
    )
  )

  ; Load user settings or default
  (setq input_data (load_last_data))
  (setq base_diam_str (cdr (assoc 'base_diam input_data)))
  (setq forest_sel   (cdr (assoc 'forest input_data)))
  (setq town_sel (cdr (assoc 'town input_data)))

  ; Launch dialog and update input
  (setq input_data (run_dialog dcl_id base_diam_str forest_sel town_sel))

  (if input_data
    (progn
      (setq base_diam_str  (nth 0 input_data))
      (setq base_diam_num  (nth 1 input_data))
      (setq forest_sel    (nth 2 input_data))
      (setq town_sel  (nth 3 input_data))
      (save_data base_diam_str forest_sel town_sel)
    )
  )

  ; Setup enviroment
  (setup_environment)

  ; Create base
  (create_base base_diam_num)

  ; Create forest if selected
  (if (= forest_sel "1")
    (progn
      (setq tree_points (generate_coords (* base_diam_num 0.9)))
  	(foreach pt tree_points
	  (setq r (random_float))
	  
	  (cond
	    ((< r 0.7)
	     (create_tree pt base_diam_num
	       (+ (/ base_diam_num 60.0) (* (random_float) (* 2 pi (random_float))))))
	    ((< r 0.85)
	     (create_rock pt base_diam_num
	       (+ (/ base_diam_num 60.0) (* (random_float) (* 2 pi (random_float))))))
	    (T
	     (create_flower pt base_diam_num
	       (+ (/ base_diam_num 75.0) (* (random_float) (* 2 pi (random_float))))))
	    )
	  )
    )
  )

  ; Create town if selected
  (if (= town_sel "1")
    (progn
      (setq town_points (generate_grid (* base_diam_num 0.7)))
      
      (foreach pt town_points
	(create_skyscraper pt base_diam_num
	  (+ (/ base_diam_num 60.0) (* (random_float) (* 2 pi (random_float))))))
    )
  )

  ; Restore snaps
  (enable_onsnap)

  ; Clean up dialog resources
  (unload_dialog dcl_id)
  (princ)
)