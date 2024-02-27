require 'sketchup.rb'

module VM
  module FirstReflectionsCalculator

    class FirstReflectionsTool
      # Set-up instance variables when the tool is activated
      def activate
        @mouse_ip = Sketchup::InputPoint.new # Input Point is used to pick 3d point, which reside under the cursor
        @face = nil
        @model = Sketchup.active_model # Get active model
        @entities = @model.entities # Get entities class; Needed to spawn CLines
      end

      # Method when user presses the Left Mouse Button
      def onLButtonDown(flag, x, y, view)
        @mouse_ip.pick(view, x, y) # Pick the 3D point below the cursor

        @face = @mouse_ip.face # Get face that the cursor has been clicked on
        if @face.nil?
          UI.messagebox("Point must be on a face.")
          return
        end

        n_of_reflections = UI.inputbox(["How many rays do you want to cast?"], [20], "Number of rays.")[0]
        calculate_first_reflections(n_of_reflections)
      end

      def calculate_first_reflections(n_of_reflections)
        @model.start_operation('Calculate Reflections', true)
        n_of_reflections.times do
          shoot_ray(@face.normal, @mouse_ip.position)
        end
        @model.commit_operation
      end

      def shoot_ray(normal, source)
        # Target - centre of the circle 1 meter away from the mouse position in the direction of the face normal
        target = source.offset(normal, 1.m)
        direction = source.vector_to(target)

        #
        tr = Geom::Transformation.new(target, direction)

        # Angle will hold a random angle in the range [0, 2π), which represents a full circle in radians
        angle = rand * 2 * Math::PI

        # Calculate a random radius "slice" in a circle with 1m radius using a uniform formula
        # http://www.anderswallin.net/2009/05/uniform-random-points-in-a-circle-using-polar-coordinates/
        random_radius = 1.m * Math.sqrt(rand)

        # Generate random 2D coordinates (x and y) that are evenly distributed around a circle with a radius of random_radius
        x = random_radius * Math.sin(angle)
        y = random_radius * Math.cos(angle)

        random_point = Geom::Point3d.new(x, y, 0)
        # Transform random_point to a new position relative to the target point and aligned with the direction vector
        random_point.transform!(tr)

        hit = @model.raytest(source, source.vector_to(random_point)) # Cast a ray through the model and return the first thing it hits
        if hit.nil?
          # UI.messagebox("Ray didn't hit anything.")
          return
        end

        @entities.add_cline(source, hit[0]) # Add a finite CLine from the mouse Input Point to rays first hit.
        puts("Added CLine")
      end
    end

    # Reload extension.
    #
    # @param clear_console [Boolean] Whether console should be cleared.
    # @param undo [Boolean] Whether last oration should be undone.
    #
    # @return [void]
    def self.reload(clear_console = true, undo = false)
      # Hide warnings for already defined constants.
      verbose = $VERBOSE
      $VERBOSE = nil
      Dir.glob(File.join(PATH_ROOT, "**/*.{rb,rbe}")).each { |f| load(f) }
      $VERBOSE = verbose

      # Use a timer to make call to method itself register to console.
      # Otherwise the user cannot use up arrow to repeat command.
      UI.start_timer(0) { SKETCHUP_CONSOLE.clear } if clear_console

      Sketchup.undo if undo

      nil
    end

    def self.activate_line_tool
      Sketchup.active_model.select_tool(FirstReflectionsTool.new)
    end

    unless file_loaded?(__FILE__)
      menu = UI.menu('Plugins')
      menu.add_item('First Reflections Tool') {
        self.activate_line_tool
      }
      file_loaded(__FILE__)
    end

  end
end