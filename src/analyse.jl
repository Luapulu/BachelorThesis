calcenergy(event::MaGeEvent)::Float32 = sum(hit.E for hit in event)

"""Convert to detector coordinates [mm]"""
function todetectorcoords(x, y, z, xtal_length)
    x = 10(x + 200)
    y = 10y
    z = -10z + 0.5xtal_length
    return x, y, z
end
