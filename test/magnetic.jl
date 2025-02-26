# See https://github.com/singularitti/Spglib.jl/issues/91#issuecomment-1206106977
@testset "Test example given by Jae-Mo Lihm (@jaemolihm)" begin
    lattice = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]
    positions = [[-0.1, -0.1, -0.1], [0.1, 0.1, 0.1]]
    atoms = [1, 1]
    magmoms = [[0.0, 0.0, 1.0], [0.0, 0.0, -1.0]]
    cell = Cell(lattice, positions, atoms, magmoms)
    rotations, translations = get_symmetry(cell, 1e-5)
    @test size(rotations) == size(translations) == (12,)
    rotations, translations, equivalent_atoms = get_magnetic_symmetry(cell, 1e-5)
    @test size(rotations) == size(translations) == (4,)
end

# From https://github.com/unkcpz/LibSymspg.jl/blob/53d2f6d/test/test_api.jl#L34-L77
@testset "Get symmetry operations" begin
    @testset "Normal symmetry" begin
        lattice = [[4, 0, 0], [0, 4, 0], [0, 0, 4]]
        positions = [[0, 0, 0], [0.5, 0.5, 0.5]]
        atoms = [1, 1]
        cell = Cell(lattice, positions, atoms, [0, 0])
        rotations, translations = get_symmetry(cell, 1e-5)
        @test size(rotations) == (96,)
        @test size(translations) == (96,)
        @test get_hall_number_from_symmetry(cell, 1e-5) == 529
    end
    # See https://github.com/spglib/spglib/blob/378240e/python/test/test_collinear_spin.py#L18-L37
    @testset "Get symmetry with collinear spins" begin
        lattice = [
            4.0 0.0 0.0
            0.0 4.0 0.0
            0.0 0.0 4.0
        ]
        positions = [[0.0, 0.0, 0.0], [0.5, 0.5, 0.5]]
        atoms = [1, 1]
        @testset "Test ferromagnetism" begin
            magmoms = [1.0, 1.0]
            cell = Cell(lattice, positions, atoms, magmoms)
            rotations, translations, equivalent_atoms = get_symmetry_with_collinear_spin(
                cell, 1e-5
            )
            @test size(rotations) == (96,)
            @test size(translations) == (96,)
            @test all(iszero(translation) for translation in translations[1:48])
            @test all(
                translation == [1 / 2, 1 / 2, 1 / 2] for translation in translations[49:96]
            )  # Compared with Python
            @test equivalent_atoms == [0, 0]
        end
        @testset "Test antiferromagnetism" begin
            magmoms = [1.0, -1.0]
            cell = Cell(lattice, positions, atoms, magmoms)
            rotations, translations, equivalent_atoms = get_symmetry_with_collinear_spin(
                cell, 1e-5
            )
            @test size(rotations) == (3, 3, 96)
            @test equivalent_atoms == [0, 0]
        end
        @testset "Test broken magmoms" begin
            magmoms = [1.0, 2.0]
            cell = Cell(lattice, positions, atoms, magmoms)
            rotations, translations, equivalent_atoms = get_symmetry_with_collinear_spin(
                cell, 1e-5
            )
            @test size(rotations) == (3, 3, 48)
            @test size(translations) == (3, 48)
            @test equivalent_atoms == [0, 1]
        end
    end
end
