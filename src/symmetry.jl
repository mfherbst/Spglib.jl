# See https://github.com/spglib/spglib/blob/444e061/python/spglib/spglib.py#L115-L165
"""
    get_symmetry(cell::Cell, symprec=1e-5)

Return the symmetry operations of a `cell`.
"""
function get_symmetry(cell::Cell, symprec=1e-5)
    lattice, positions, atoms = _expand_cell(cell)
    n = natoms(cell)
    # See https://github.com/spglib/spglib/blob/42527b0/python/spglib/spglib.py#L270
    max_size = 48n  # Num of symmetry operations = order of the point group of the space group × num of lattice points
    rotations = Array{Cint,3}(undef, 3, 3, max_size)
    translations = Array{Cdouble,2}(undef, 3, max_size)  # C is row-major order, but Julia is column-major order
    nsym = @ccall libsymspg.spg_get_symmetry(
        rotations::Ptr{Cint},
        translations::Ptr{Cdouble},
        max_size::Cint,
        lattice::Ptr{Cdouble},
        positions::Ptr{Cdouble},
        atoms::Ptr{Cint},
        n::Cint,
        symprec::Cdouble,
    )::Cint
    check_error()
    rotations, translations = map(
        SMatrix{3,3,Int32,9}, eachslice(rotations[:, :, 1:nsym]; dims=3)
    ),
    map(SVector{3,Float64}, eachcol(translations[:, 1:nsym]))
    return rotations, translations
end

"""
    get_symmetry_from_database(hall_number)

Return the symmetry operations given a `hall_number`.

This function allows to directly access to the space group operations in the
`spglib` database. To specify the space group type with a specific choice,
`hall_number` is used.
"""
function get_symmetry_from_database(hall_number)
    # The maximum number of symmetry operations is 192, see https://github.com/spglib/spglib/blob/77a8e5d/src/spglib.h#L382
    rotations = Array{Cint,3}(undef, 3, 3, 192)
    translations = Array{Cdouble,2}(undef, 3, 192)
    nsym = @ccall libsymspg.spg_get_symmetry_from_database(
        rotations::Ptr{Cint}, translations::Ptr{Cdouble}, hall_number::Cint
    )::Cint
    check_error()
    rotations, translations = map(
        SMatrix{3,3,Int32,9}, eachslice(rotations[:, :, 1:nsym]; dims=3)
    ),
    map(SVector{3,Float64}, eachcol(translations[:, 1:nsym]))
    return rotations, translations
end

function get_spacegroup_type_from_symmetry(cell::AbstractCell, symprec=1e-5)
    rotations, translations = get_symmetry(cell, symprec)
    nsym = length(translations)
    rotations, translations = reduce(hcat, rotations), reduce(hcat, translations)
    spgtype = @ccall libsymspg.spg_get_spacegroup_type_from_symmetry(
        rotations::Ptr{Cint},
        translations::Ptr{Cdouble},
        nsym::Cint,
        Lattice(cell)::Ptr{Cdouble},
        symprec::Cdouble,
    )::SpglibSpacegroupType
    return convert(SpacegroupType, spgtype)
end

"""
    get_hall_number_from_symmetry(rotation::AbstractArray{T,3}, translation::AbstractMatrix, num_operations::Integer, symprec=1e-5) where {T}

Obtain `hall_number` from the set of symmetry operations.

This is expected to work well for the set of symmetry operations whose
distortion is small. The aim of making this feature is to find space-group-type
for the set of symmetry operations given by the other source than spglib. Note
that the definition of `symprec` is different from usual one, but is given in the
fractional coordinates and so it should be small like `1e-5`.
"""
function get_hall_number_from_symmetry(
    rotation::AbstractArray{T,3},
    translation::AbstractMatrix,
    num_operations::Integer,
    symprec=1e-5,
) where {T}
    rotation = Base.cconvert(Array{Cint,3}, rotation)
    translation = Base.cconvert(Matrix{Cdouble}, translation)
    num_operations = Base.cconvert(Cint, num_operations)
    return ccall(
        (:spg_get_hall_number_from_symmetry, libsymspg),
        Cint,
        (Ptr{Cint}, Ptr{Float64}, Cint, Float64),
        rotation,
        translation,
        num_operations,
        symprec,
    )
end

@deprecate get_hall_number_from_symmetry get_spacegroup_type_from_symmetry

"""
    get_multiplicity(cell::Cell, symprec=1e-5)

Return the exact number of symmetry operations. An error is thrown when it fails.
"""
function get_multiplicity(cell::AbstractCell, symprec=1e-5)
    lattice, positions, types = _expand_cell(cell)
    num_atom = Base.cconvert(Cint, length(types))
    num_sym = ccall(
        (:spg_get_multiplicity, libsymspg),
        Cint,
        (Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cint}, Cint, Cdouble),
        lattice,
        positions,
        types,
        num_atom,
        symprec,
    )
    check_error()
    return num_sym
end

"""
    get_dataset(cell::Cell, symprec=1e-5)

Search symmetry operations of an input unit cell structure.
"""
function get_dataset(cell::AbstractCell, symprec=1e-5)
    lattice, positions, atoms = _expand_cell(cell)
    ptr = @ccall libsymspg.spg_get_dataset(
        lattice::Ptr{Cdouble},
        positions::Ptr{Cdouble},
        atoms::Ptr{Cint},
        natoms(cell)::Cint,
        symprec::Cdouble,
    )::Ptr{SpglibDataset}
    if ptr == C_NULL
        return nothing
    else
        raw = unsafe_load(ptr)
        return convert(Dataset, raw)
    end
end

"""
    get_dataset_with_hall_number(cell::Cell, hall_number::Integer, symprec=1e-5)

Search symmetry operations of an input unit cell structure, using a given Hall number.
"""
function get_dataset_with_hall_number(
    cell::AbstractCell, hall_number::Integer, symprec=1e-5
)
    lattice, positions, types = _expand_cell(cell)
    num_atom = Base.cconvert(Cint, length(types))
    hall_number = Base.cconvert(Cint, hall_number)
    ptr = ccall(
        (:spg_get_dataset_with_hall_number, libsymspg),
        Ptr{SpglibDataset},
        (Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cint}, Cint, Cint, Cdouble),
        lattice,
        positions,
        types,
        num_atom,
        hall_number,
        symprec,
    )
    if ptr == C_NULL
        return nothing
    else
        raw = unsafe_load(ptr)
        return convert(Dataset, raw)
    end
end

"""
    get_spacegroup_type(hall_number::Integer)

Translate Hall number to space group type information.
"""
function get_spacegroup_type(hall_number::Integer)
    spgtype = ccall(
        (:spg_get_spacegroup_type, libsymspg), SpglibSpacegroupType, (Cint,), hall_number
    )
    return convert(SpacegroupType, spgtype)
end

"""
    get_spacegroup_number(cell::Cell, symprec=1e-5)

Get the spacegroup number of a `cell`.
"""
function get_spacegroup_number(cell::AbstractCell, symprec=1e-5)
    dataset = get_dataset(cell, symprec)
    return dataset.spacegroup_number
end
"""
    get_spacegroup_type(cell::Cell, symprec=1e-5)

Get `SpacegroupType` from `cell`.
"""
function get_spacegroup_type(cell::AbstractCell, symprec=1e-5)  # See https://github.com/spglib/spglib/blob/444e061/python/spglib/spglib.py#L307-L324
    dataset = get_dataset(cell, symprec)
    return get_spacegroup_type(dataset.hall_number)
end

"""
    get_international(cell::Cell, symprec=1e-5)

Return the space group type in Hermann–Mauguin (international) notation.
"""
function get_international(cell::AbstractCell, symprec=1e-5)
    lattice, positions, types = _expand_cell(cell)
    symbol = Vector{Cchar}(undef, 11)
    ccall(
        (:spg_get_international, libsymspg),
        Cint,
        (Ptr{Cchar}, Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cint}, Cint, Cdouble),
        symbol,
        lattice,
        positions,
        types,
        length(types),
        symprec,
    )
    check_error()
    return tostring(symbol)
end

"""
    get_schoenflies(cell::Cell, symprec=1e-5)

Return the space group type in Schoenflies notation.
"""
function get_schoenflies(cell::AbstractCell, symprec=1e-5)
    lattice, positions, types = _expand_cell(cell)
    symbol = Vector{Cchar}(undef, 7)
    ccall(
        (:spg_get_schoenflies, libsymspg),
        Cint,
        (Ptr{Cchar}, Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cint}, Cint, Cdouble),
        symbol,
        lattice,
        positions,
        types,
        length(types),
        symprec,
    )
    check_error()
    return tostring(symbol)
end
