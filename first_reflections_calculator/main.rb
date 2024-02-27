require 'sketchup.rb'

module VM
  module FirstReflectionsCalculator

    class FirstReflectionsTool
      # Set-up instance variables when the tool is activated
      def activate
        @mouse_ip = Sketchup::InputPoint.new         # Input Point is used to pick 3d point, which reside under the cursor

        @model = Sketchup.active_model # Get active model
        @entities = @model.entities # Get entities class; Needed to spawn CLines
      end

      # Method when user presses the Left Mouse Button
      def onLButtonDown(flag, x, y, view)
        @mouse_ip.pick(view, x, y) # Pick the 3D point below the cursor

        face = @mouse_ip.face # Get face that the cursor has been clicked on
        if face.nil?
          UI.messagebox("Point must be on a face.")
          return
        end

        shoot_ray(face.normal)
      end

      def shoot_ray(normal)
        mouse_position = @mouse_ip.position
        target = mouse_position.offset(normal, 1.m)
        direction = mouse_position.vector_to(target)

        tr = Geom::Transformation.new(target, direction)

        @entities.add_cline(@mouse_ip.position, target)

        angle = rand * 2 * Math::PI

        random_radius = 1.m * Math.sqrt( rand )

        x = random_radius * Math.sin( angle )
        y = random_radius * Math.cos( angle )

        random_point = Geom::Point3d.new( x, y, 0 )
        random_point.transform!( tr )

        @entities.add_cpoint(random_point)

        hit = @model.raytest(@mouse_ip.position, mouse_position.vector_to(random_point)) # Cast a ray through the model and return the first thing it hits
        if hit.nil?
          # UI.messagebox("Ray didn't hit anything.")
          return
        end

        @entities.add_cline(@mouse_ip.position, hit[0]) # Add a finite CLine from the mouse Input Point to rays first hit.
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