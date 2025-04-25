
import mdtraj as md

#################################################################################
# Script Name: mdalign.py
# Description: This script aligns a target structure to a reference using alpha carbon positions (CA). 
# It is used as an approximative alignment prior to running MD-simulations           
# Author: [Per Söderhjelm, Anton Sellerberg]
# Date: [09-08-24]
#################################################################################

# Load the reference structure from a PDB file
# This structure will be used as the reference for alignment
ref = md.load('complex_ref.pdb')

# Load the target structure from a PDB file
# This is the structure that will be aligned to the reference
t = md.load('pose.pdb')

# Superpose the target structure onto the reference structure
# The alignment is done using the alpha carbon atoms (CA) of the protein
t.superpose(ref, atom_indices=t.topology.select("name CA"))

# Alignment done, now output the coordinates

# Extract the protein chains (chain IDs 0 and 1) from the aligned target structure
# The atom_slice method selects a subset of atoms based on the specified criteria
prot = t.atom_slice(t.topology.select("chainid 0 1"))

# Save the extracted protein chains to a new PDB file
prot.save('alignedprot.pdb')

# Extract the ligand with residue name UNK from the aligned target structure
lig = t.atom_slice(t.topology.select("resname UNK"))

# Save the extracted ligand to a new PDB file
lig.save('lig.pdb')

# Extract the static ligands with residue names EEE and DCK from the reference structure
# These ligands are not part of the alignment but are saved for reference
staticligands = ref.atom_slice(ref.topology.select("resname EEE DCK"))

# Save the extracted static ligands to a new PDB file
staticligands.save('staticligands.pdb')