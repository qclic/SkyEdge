#!/bin/bash
# dnf -y install isomd5sum syslinux genisoimage

set -e

openeuler_iso_url="https://repo.openeuler.org/openEuler-22.03-LTS/ISO/x86_64/openEuler-22.03-LTS-x86_64-dvd.iso"
name="SkyEdge"
version="1.0"
timestamp="$(date +%Y%m%d%H%M)"
label="$name"
iso_ori="openEuler-22.03-LTS-x86_64-dvd.iso"

download_iso() {
    if [ ! -f ${iso_ori} ]; then
        wget ${openeuler_iso_url}
    fi
}

edit_iso() {
    tmpdir=$(mktemp -d -p .)
    mount -v ${iso_ori} ${tmpdir}
    rm -rf isodir
    cp -a ${tmpdir} isodir
    umount -v ${tmpdir}

    cfgs="isodir/isolinux/isolinux.cfg isodir/EFI/BOOT/grub.cfg ${tmpdir}/EFI/BOOT/grub.cfg"
    mount -v isodir/images/efiboot.img ${tmpdir}
    sed -i \
      -e "s/openEuler/${name}/g" \
      -e "s/22.03-LTS/${version}/g" \
      -e "s/hd:LABEL=[^ :]*/hd:LABEL=${label}/g" \
      -e "/stage2/ s%$% inst.ks=hd:LABEL=${label}:/ks/ks.cfg%" \
      ${cfgs}
    while ! umount -v ${tmpdir}; do
        sleep 3
    done

    rm -rfv ${tmpdir}

    cp -av files/rpms isodir/others

    rm -rf isodir/repodata
    createrepo -g $(pwd)/files/comps.xml isodir/

    mkdir -p isodir/ks
    cp -v files/ks.cfg isodir/ks/

    echo "name=${name}" > isodir/version
    echo "version=${version}" >> isodir/version

}

product_img() {
    mkdir -pv product/usr/share/anaconda/pixmaps/
    mkdir -pv product/etc/anaconda/product.d/
    cp -v logo/sidebar-logo.png product/usr/share/anaconda/pixmaps/
    cp -v files/skyedge.conf product/etc/anaconda/product.d/
    pushd product
    cat > .buildstamp << EOF
[Main]
Product=${name}
Version=${version}
BugURL=your distribution provided bug reporting tool
IsFinal=True
UUID=${timestamp}.x86_64
[Compose]
Lorax=33.6-1
EOF
    find . | cpio -c -o --quiet | pigz -9c > ../isodir/images/product.img
    popd

    rm -rfv product
}

create_iso() {
    rm -rfv ${name}-*.iso
    mkisofs -J -T -U \
        -joliet-long \
        -allow-limited-size \
        -o ${name}-${version}.iso \
        -b isolinux/isolinux.bin \
        -c isolinux/boot.cat \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        -eltorito-alt-boot \
        -e images/efiboot.img \
        -no-emul-boot \
        -R \
        -graft-points \
        -A "${label}" \
        -V "${label}" \
        isodir
    isohybrid -u ${name}-${version}.iso
    implantisomd5 --force ${name}-${version}.iso
}

download_iso
edit_iso
product_img
create_iso

